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
 * still shows each status, refreshed every few seconds.
 */
import { appendFileSync, mkdirSync, readFileSync, statSync } from 'node:fs'
import { connect, createServer } from 'node:net'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

const CONFIG = join(dirname(fileURLToPath(import.meta.url)), 'cube.json')
const DIR = '/tmp/claude-lamp'
const STATE = join(DIR, '.state')
const TIMEOUT_MS = 3000
const FADE_MS = 400
const RETRY_MS = 10000
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
    socket.setTimeout(TIMEOUT_MS, () => socket.destroy(new Error('timed out')))
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
    if (stream === socket) stream = null
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
let lit = true // assume on, so the first dark frame turns it off
let pending = false // a command connection is open
let retryAt = 0
let last = null // the last frame's LEDs, to fade from
let fadeFrom = null
let fadeAt = 0

const control = (commands, onDone) => {
  pending = true
  send(commands)
    .then(onDone, (error) => {
      log(`cube: ${error.message}`)
      retryAt = Date.now() + RETRY_MS
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
  if (!look || idleOver) {
    last = null
    if (lit && !pending && now >= retryAt) control([['set_power', ['off', 'smooth', 800]]], () => (lit = false))
    return
  }

  let leds = render(look, now - changedAt)
  if (fadeFrom && now - fadeAt < FADE_MS) leds = leds.map((c, i) => mix(fadeFrom[i] ?? c, c, (now - fadeAt) / FADE_MS))
  last = leds
  const frame = encode(leds)

  if (stream && lit) {
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
        lit = true
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
