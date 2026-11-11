#!/usr/bin/env node
/**
 * Animates a Yeelight Cube with the Claude Code status that lamp-hook.sh writes to /tmp/claude-lamp/.state.
 *
 *   node cube.mjs    # runs until stopped; launchd keeps it running (see README.md)
 *
 * Each status has two colours, an animation and a cycle length in cube.json, next to this file, which is re-read
 * whenever it changes. The animations are drawn around each 5x5 cube's centre, so they look the same however the
 * cubes are stacked. It speaks Yeelight's LAN protocol (JSON lines over TCP, port 55443) the way the YeelightMatrix
 * library does: set_power, activate_fx_mode "direct", and update_leds with one base64 RGB triple per LED. Frames go
 * over "music mode", a connection the cube opens back to this process and doesn't rate-limit; without it the cube
 * still shows each status, refreshed every few seconds. Dark is black frames, never set_power off: a cube that's
 * powered off can take minutes to answer again, until it restarts. When the cube doesn't answer at its address,
 * Yeelight's SSDP discovery finds where it is now, and the address is saved in cube.json.
 */
import { spawnSync } from 'node:child_process'
import { createSocket } from 'node:dgram'
import {
  appendFileSync,
  closeSync,
  mkdirSync,
  openSync,
  readdirSync,
  readFileSync,
  readSync,
  statSync,
  writeFileSync,
} from 'node:fs'
import { connect, createServer } from 'node:net'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

const CONFIG = join(dirname(fileURLToPath(import.meta.url)), 'cube.json')
const HOOK = join(dirname(fileURLToPath(import.meta.url)), 'lamp-hook.sh')
const DIR = '/tmp/claude-lamp'
const STATE = join(DIR, '.state')
const TIMEOUT_MS = 3000
const FADE_MS = 400
const RETRY_MS = 10000
const DISCOVER_MS = 2000
mkdirSync(DIR, { recursive: true })

const log = (message) => appendFileSync(join(DIR, 'cube.log'), `${new Date().toISOString()} ${message}\n`)

const read = (file) => {
  try {
    return readFileSync(file, 'utf8').trim()
  } catch {
    return ''
  }
}

let config = null
let configTime = 0
let configCheckedAt = 0
const loadConfig = () => {
  let time
  try {
    time = statSync(CONFIG).mtimeMs
  } catch {
    return
  }
  if (time === configTime) return
  configTime = time
  try {
    config = JSON.parse(readFileSync(CONFIG, 'utf8'))
    log('loaded cube.json')
  } catch (error) {
    log(`cube.json: ${error.message}`)
  }
}
loadConfig()
if (!config) process.exit(1)

const rgb = (hex) => [1, 3, 5].map((i) => parseInt(hex.slice(i, i + 2), 16))
const mix = (a, b, t) => a.map((channel, i) => channel + (b[i] - channel) * t)
const dim = (color, k) => color.map((channel) => channel * k)
// 0 → 1 → 0 over one cycle
const wave = (t) => 0.5 - 0.5 * Math.cos(2 * Math.PI * t)

// The colour of one LED from the status's two colours, its distance from the centre (0 to 1), its angle and the time
// in cycles
const ANIMATIONS = {
  still: (a, b, r) => mix(a, b, r),
  breathe: (a, b, r, angle, t) => dim(mix(a, b, r), 0.55 + 0.45 * wave(t)),
  pulse: (a, b, r, angle, t) => dim(mix(a, b, r), 0.1 + 0.9 * wave(t) ** 2),
  spin: (a, b, r, angle, t) => (r === 0 ? mix(a, b, 0.5) : mix(a, b, wave(angle / (2 * Math.PI) - t))),
  ripple: (a, b, r, angle, t) => mix(a, b, wave(r - t)),
}

const GRID = []
for (let y = 0; y < 5; y++) {
  for (let x = 0; x < 5; x++) GRID.push([Math.hypot(x - 2, y - 2) / Math.hypot(2, 2), Math.atan2(y - 2, x - 2)])
}
// A 1x1 spotlight samples a point off the centre, so a spinning status still changes its colour
const SPOT = [[0.5, 0]]
const DARK = { colors: ['#000000', '#000000'], animation: 'still' }

const render = (look, ms) => {
  const [a, b] = look.colors.map(rgb)
  const draw = ANIMATIONS[look.animation] ?? ANIMATIONS.still
  const t = ms / 1000 / (look.seconds || 1)
  return config.modules.flatMap((type) => (type === '1x1' ? SPOT : GRID).map(([r, angle]) => draw(a, b, r, angle, t)))
}

const encode = (leds) =>
  leds.map((c) => Buffer.from(c.map((v) => Math.max(0, Math.min(255, Math.round(v))))).toString('base64')).join('')

// Sends commands over a fresh connection, each after the previous one is acknowledged. A command can be a function
// of the socket, for parameters that depend on it.
const send = (commands) =>
  new Promise((resolve, reject) => {
    const socket = connect(config.port ?? 55443, config.ip)
    socket.setTimeout(TIMEOUT_MS, () =>
      socket.destroy(new Error(socket.connecting ? 'connect timed out' : `${method} timed out`)),
    )
    socket.on('error', reject)
    let buffer = ''
    let sent = 0
    let method = ''
    const next = () => {
      if (sent === commands.length) {
        socket.end()
        resolve()
        return
      }
      const command = commands[sent++]
      const [name, params] = typeof command === 'function' ? command(socket) : command
      method = name
      socket.write(`${JSON.stringify({ id: sent, method, params })}\r\n`)
      // The cube never acknowledges update_leds
      if (method === 'update_leds') next()
    }
    socket.on('connect', next)
    socket.on('data', (chunk) => {
      buffer += chunk
      let end
      while ((end = buffer.indexOf('\n')) >= 0) {
        const line = buffer.slice(0, end).trim()
        buffer = buffer.slice(end + 1)
        let reply
        try {
          reply = JSON.parse(line)
        } catch {
          continue
        }
        // The cube also sends unprompted property notifications, without an id
        if (reply.id !== sent) continue
        if (reply.error) {
          socket.destroy(new Error(`${method}: ${JSON.stringify(reply.error)}`))
          return
        }
        next()
      }
    })
  })

// The address of the first device on the network that answers Yeelight's discovery and takes per-LED frames, or null
const SEARCH = 'M-SEARCH * HTTP/1.1\r\nHOST: 239.255.255.250:1982\r\nMAN: "ssdp:discover"\r\nST: wifi_bulb\r\n'
const discover = () =>
  new Promise((resolve) => {
    const socket = createSocket('udp4')
    let finished = false
    const done = (ip) => {
      if (finished) return
      finished = true
      clearTimeout(timer)
      socket.close()
      resolve(ip)
    }
    const timer = setTimeout(() => done(null), DISCOVER_MS)
    socket.on('error', () => done(null))
    socket.on('message', (message) => {
      const headers = {}
      for (const line of message.toString().split('\r\n')) {
        const colon = line.indexOf(':')
        if (colon > 0) headers[line.slice(0, colon).trim().toLowerCase()] = line.slice(colon + 1).trim()
      }
      if (!headers.support?.split(' ').includes('update_leds')) return
      const ip = headers.location?.match(/^yeelight:\/\/([\d.]+):/)?.[1]
      if (ip) done(ip)
    })
    socket.bind(() => socket.send(SEARCH, 1982, '239.255.255.250', (error) => error && done(null)))
  })

// Follows the cube to its new address, saved in cube.json for the next start
const moveTo = (ip) => {
  log(`cube found at ${ip}`)
  config.ip = ip
  try {
    writeFileSync(CONFIG, readFileSync(CONFIG, 'utf8').replace(/"ip":\s*"[^"]*"/, `"ip": "${ip}"`))
  } catch (error) {
    log(`cube.json: ${error.message}`)
  }
}

// Music mode: the cube connects here and then takes frames without acknowledging them
const MUSIC_PORT = config.musicPort ?? 54321
let stream = null
createServer((socket) => {
  if (socket.remoteAddress?.replace('::ffff:', '') !== config.ip) {
    socket.destroy()
    return
  }
  stream?.destroy()
  stream = socket
  socket.setNoDelay(true)
  socket.on('error', () => {})
  socket.on('close', () => {
    if (stream !== socket) return
    stream = null
    log('music mode closed')
  })
  log('music mode connected')
})
  .on('error', (error) => {
    log(`music port ${MUSIC_PORT}: ${error.message}`)
    process.exit(1)
  })
  .listen(MUSIC_PORT)

let shown = null // the status on the cube
let changedAt = Date.now()
let dark = false
let pending = false // a command connection is open
let retryAt = 0
let last = null // the last frame's LEDs, to fade from
let fadeFrom = null
let fadeAt = 0

const control = (commands, onDone) => {
  pending = true
  send(commands)
    .then(onDone, async (error) => {
      log(`cube: ${error.message}`)
      retryAt = Date.now() + RETRY_MS
      const ip = await discover()
      if (ip && ip !== config.ip) {
        moveTo(ip)
        retryAt = 0
      }
    })
    .finally(() => {
      pending = false
    })
}

const tick = () => {
  const now = Date.now()
  if (now - configCheckedAt > 1000) {
    configCheckedAt = now
    loadConfig()
  }
  const status = read(STATE) || 'off'
  if (status !== shown) {
    log(`status ${status}`)
    fadeFrom = last
    fadeAt = now
    shown = status
    changedAt = now
    retryAt = 0
  }

  const look = config.states[shown]
  const idleOver = shown === 'idle' && config.idleOffMinutes > 0 && now - changedAt > config.idleOffMinutes * 60000
  if ((!look || idleOver) !== dark) {
    dark = !dark
    fadeFrom = last
    fadeAt = now
  }

  let leds = render(dark ? DARK : look, now - changedAt)
  if (fadeFrom && now - fadeAt < FADE_MS) leds = leds.map((c, i) => mix(fadeFrom[i] ?? c, c, (now - fadeAt) / FADE_MS))
  last = leds
  const frame = encode(leds)

  if (stream) {
    stream.write(`${JSON.stringify({ id: 1, method: 'update_leds', params: [frame] })}\r\n`)
    return
  }
  // Not streaming yet: power on, switch to per-LED control, show this frame and ask the cube to connect back
  if (!pending && now >= retryAt) {
    control(
      [
        ['set_power', ['on', 'smooth', 300]],
        ['activate_fx_mode', [{ mode: 'direct' }]],
        ['update_leds', [frame]],
        (socket) => ['set_music', [1, socket.localAddress.replace('::ffff:', ''), MUSIC_PORT]],
      ],
      () => {
        if (!stream) retryAt = Date.now() + RETRY_MS
      },
    )
  }
}

setInterval(
  () => {
    try {
      tick()
    } catch (error) {
      log(`tick: ${error.stack}`)
    }
  },
  1000 / (config.fps ?? 12),
)

// The last message in a transcript, if the transcript changed after the given time
const TAIL_BYTES = 65536
const lastMessage = (transcript, since) => {
  let fd
  try {
    const { size, mtimeMs } = statSync(transcript)
    if (mtimeMs <= since) return null
    fd = openSync(transcript, 'r')
    const length = Math.min(size, TAIL_BYTES)
    const tail = Buffer.alloc(length)
    readSync(fd, tail, 0, length, size - length)
    for (const line of tail.toString('utf8').split('\n').reverse()) {
      let entry
      try {
        entry = JSON.parse(line)
      } catch {
        continue
      }
      if (entry.type === 'user' || entry.type === 'assistant') return entry
    }
    return null
  } catch {
    return null
  } finally {
    if (fd !== undefined) closeSync(fd)
  }
}

const isInterrupt = (entry) =>
  entry?.type === 'user' &&
  Array.isArray(entry.message?.content) &&
  entry.message.content.some((part) => part.type === 'text' && part.text?.startsWith('[Request interrupted by user'))

const isRunning = (pid) => {
  try {
    process.kill(pid, 0)
    return true
  } catch (error) {
    return error.code === 'EPERM'
  }
}

const runHook = (state, input) => spawnSync('/bin/bash', [HOOK, state], { input: JSON.stringify(input) })

// When the Bash tool's commands running under each of the given Claude processes started, in ms. Claude runs each
// command in a shell that sources one of its shell snapshots.
const bashStarts = (pids) => {
  const starts = new Map(pids.map((pid) => [pid, []]))
  const { stdout } = spawnSync('/bin/ps', ['-A', '-ww', '-o', 'ppid=,etime=,command='], { encoding: 'utf8' })
  const now = Date.now()
  for (const line of stdout?.split('\n') ?? []) {
    const [, ppid, elapsed, command] = line.match(/^\s*(\d+)\s+(\S+)\s+(.*)$/) ?? []
    if (!starts.has(Number(ppid)) || !command.includes('/shell-snapshots/')) continue
    // [[dd-]hh:]mm:ss
    const [days, clock] = elapsed.includes('-') ? elapsed.split('-') : [0, elapsed]
    const seconds = clock.split(':').reduce((total, part) => total * 60 + Number(part), Number(days) * 24)
    starts.get(Number(ppid)).push(now - seconds * 1000)
  }
  return starts
}

// A session ends without SessionEnd when its process exits or moves on to another session (a fork, a resume, a
// crash), so it's dropped then. An interrupt fires no hook, so a busy session whose transcript ends with one since its
// last hook goes idle. Accepting a permission prompt fires no hook either, and the command can run for minutes, so a
// session waiting on one goes back to working once a Bash command starts under its process. Its subagents' commands
// run there too, so not while it has any.
const checkSessions = () => {
  const names = readdirSync(DIR)
  const parents = new Set(names.filter((name) => name.includes('.')).map((name) => name.split('.')[0]))
  const sessions = []
  // Sessions only: not .state, the log or a subagent's <session>.<agent id>
  for (const session of names) {
    if (session.includes('.')) continue
    const file = join(DIR, session)
    const since = statSync(file, { throwIfNoEntry: false })?.mtimeMs
    if (!since) continue
    const [status, pid, transcript] = read(file).split('\n')
    sessions.push({ session, since, status, pid: Number(pid) || 0, transcript, stale: pid?.startsWith('/') })
  }
  const newest = new Map()
  for (const s of sessions) if (s.pid && !(newest.get(s.pid)?.since > s.since)) newest.set(s.pid, s)
  const prompts = []
  for (const s of sessions) {
    if (s.stale || (s.pid && (!isRunning(s.pid) || newest.get(s.pid) !== s))) {
      log(`session ${s.session} gone`)
      runHook('off', { session_id: s.session })
      continue
    }
    if (s.status !== 'working' && s.status !== 'input') continue
    if (s.transcript && isInterrupt(lastMessage(s.transcript, s.since))) {
      log(`session ${s.session} interrupted`)
      runHook('idle', { session_id: s.session, hook_event_name: 'Interrupt' })
    } else if (s.status === 'input' && s.pid && !parents.has(s.session)) {
      prompts.push(s)
    }
  }
  if (!prompts.length) return
  const starts = bashStarts(prompts.map((s) => s.pid))
  for (const s of prompts) {
    // ps gives each start to the second, so one in the second before the prompt doesn't count
    if (!starts.get(s.pid).some((start) => start - 1000 > s.since)) continue
    log(`session ${s.session} accepted`)
    runHook('working', { session_id: s.session, hook_event_name: 'Accept' })
  }
}

setInterval(() => {
  try {
    checkSessions()
  } catch (error) {
    log(`sessions: ${error.stack}`)
  }
}, 1000)
