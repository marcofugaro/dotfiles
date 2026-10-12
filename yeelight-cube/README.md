# Yeelight Cube as a Claude Code status light

A Yeelight Cube on your desk animates what the Claude Code sessions on the Mac mini are doing. Once it's set up it
runs on its own: it talks to the mini over Wi-Fi, comes back after reboots, and needs no extra board, no Bluetooth and
nobody logged in.

| Status | Default look |
|---|---|
| Working | A blue gradient spinning around each cube, one turn every 2 seconds |
| Needs you: a permission prompt, a question or a plan to approve | A pink-to-purple pulse, every 1.2 seconds |
| Done, your turn | A slow warm-orange breathe; turns off after 30 minutes |
| No session running | Off |

With several sessions running, the most urgent state wins: needs you, then working, then done. Colors, animations and
speeds are yours to change, and Claude can change them too (see [Colors and animations](#colors-and-animations)).

## How it works

```
Claude Code hooks (on the mini, every session)
  → lamp-hook.sh: works out the most urgent status across sessions, writes it to /tmp/claude-lamp/.state
    → cube.mjs, always running: draws that status's animation, about 12 frames a second
      → Wi-Fi, Yeelight's local protocol → Yeelight Cube
```

`cube.mjs` speaks Yeelight's local protocol the way the
[YeelightMatrix](https://github.com/VladFlorinIlie/YeelightMatrix) library does: it powers the cube on, switches it to
per-LED control and sends a color for every LED. Frames go over Yeelight's "music mode", a connection the cube opens
back to the mini, which isn't rate-limited. If that connection can't be made, the cube still shows each status as a
still frame, refreshed every 10 seconds.

## What to buy

- **A Yeelight Cube starter kit with a Panel cube:** the base plus one Panel. The Panel's diffuser blends its 25 LEDs
  into one soft, solid-looking face. The Matrix cube works too, with sharp dots instead.
- **Price:** about €68 for the starter kit (US$75.99, converted at the ECB rate of 9 October 2026); extra cubes from
  €25.99. Up to 6 cubes connect together.
- **Size:** each cube is 7.5 × 7.5 × 7.5 cm, and the base 7.5 × 7.5 × 2 cm.
- **Power:** USB-C at 5 V, with a charger in the box. Plug it into the mini or into its own charger: it only needs to
  be on your Wi-Fi, not near the mini.
- **Wi-Fi:** the cube needs a 2.4 GHz network.

## Setup

After step 1, `setup-mac-mini-status-lamp.sh` in the dotfiles folder does steps 2–5, from your admin account.

### 1. Put the cube on your network

1. Set it up with the Yeelight app, on the same Wi-Fi as the mini. If the cube's settings show **LAN Control**, turn
   it on.
2. Give it a fixed address in your router (a DHCP reservation).
3. Check the mini can reach it: `nc -z <cube IP> 55443 && echo reachable`.

### 2. Let music mode through the mini's firewall (as `<you>`)

For animations the cube connects back to the mini, and step 2 of the main guide turned the firewall on:
```sh
NODE_BIN="$(readlink -f /opt/homebrew/bin/node)"
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --add "$NODE_BIN"
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --unblockapp "$NODE_BIN"
```
- `brew upgrade node` moves that path, so run these again after upgrading Node. Until you do, the cube still shows
  each status, without animating.
- The rule lets any Node program on the mini accept connections from your home network; `cube.mjs` itself only
  accepts the cube.

### 3. Install the files (as `agent`)

From the MacBook, copy this folder to the mini:
```sh
scp -r ~/Desktop/mac-mini/yeelight-cube mini:.claude/
```
Then on the mini:
```sh
cp ~/.claude/yeelight-cube/cube.example.json ~/.claude/yeelight-cube/cube.json
nano ~/.claude/yeelight-cube/cube.json   # the cube's IP; under "modules", one entry per cube, starting from the base
```
Module types are `5x5_blur` (Panel), `5x5_clear` (Matrix) and `1x1` (Spot).

To try it, run `node ~/.claude/yeelight-cube/cube.mjs`, and in a second window run
`echo working > /tmp/claude-lamp/.state`, then `input`, `idle` and `off` the same way. Stop it with Ctrl-C.

### 4. Keep it running (as `<you>`)

launchd starts `cube.mjs` at boot as `agent` and restarts it if it stops:
```sh
sudo tee /Library/LaunchDaemons/local.claude-cube.plist >/dev/null <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>local.claude-cube</string>
  <key>UserName</key>
  <string>agent</string>
  <key>ProgramArguments</key>
  <array>
    <string>/opt/homebrew/bin/node</string>
    <string>/Users/agent/.claude/yeelight-cube/cube.mjs</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>ThrottleInterval</key>
  <integer>10</integer>
  <key>StandardOutPath</key>
  <string>/tmp/claude-cube.log</string>
  <key>StandardErrorPath</key>
  <string>/tmp/claude-cube.log</string>
</dict>
</plist>
EOF
sudo chown root:wheel /Library/LaunchDaemons/local.claude-cube.plist
sudo chmod 644 /Library/LaunchDaemons/local.claude-cube.plist
plutil -lint /Library/LaunchDaemons/local.claude-cube.plist
sudo launchctl bootstrap system /Library/LaunchDaemons/local.claude-cube.plist
```
To stop it: `sudo launchctl bootout system/local.claude-cube`.

### 5. Connect Claude Code (as `agent`)

Add this `hooks` block to `~/.claude/settings.json`, next to the settings from the main guide:
```json
"hooks": {
  "SessionStart": [{ "hooks": [{ "type": "command", "command": "bash ~/.claude/yeelight-cube/lamp-hook.sh idle" }] }],
  "UserPromptSubmit": [{ "hooks": [{ "type": "command", "command": "bash ~/.claude/yeelight-cube/lamp-hook.sh working" }] }],
  "PreToolUse": [{ "matcher": "*", "hooks": [{ "type": "command", "command": "bash ~/.claude/yeelight-cube/lamp-hook.sh working" }] }],
  "PostToolUse": [{ "matcher": "*", "hooks": [{ "type": "command", "command": "bash ~/.claude/yeelight-cube/lamp-hook.sh working" }] }],
  "PermissionRequest": [{ "matcher": "*", "hooks": [{ "type": "command", "command": "bash ~/.claude/yeelight-cube/lamp-hook.sh input" }] }],
  "Notification": [{ "matcher": "permission_prompt|elicitation_dialog", "hooks": [{ "type": "command", "command": "bash ~/.claude/yeelight-cube/lamp-hook.sh input" }] }],
  "Stop": [{ "hooks": [{ "type": "command", "command": "bash ~/.claude/yeelight-cube/lamp-hook.sh idle" }] }],
  "SessionEnd": [{ "hooks": [{ "type": "command", "command": "bash ~/.claude/yeelight-cube/lamp-hook.sh off" }] }]
}
```
Start a new session and send a prompt: the cube spins while Claude works, pulses when it asks you something, and
breathes orange when it's done.

## Colors and animations

Everything is in `~/.claude/yeelight-cube/cube.json`. Edit it, or ask Claude to ("make the working state green and
slower"): `cube.mjs` picks up the change within a second, without a restart.

Each status (`working`, `input`, `idle`) has:
- `colors`: two colors, the first for the middle of each cube and the second for its edges.
- `animation`: one of the animations below.
- `seconds`: how long one cycle of the animation takes.

| Animation | What it does |
|---|---|
| `still` | The gradient, not moving |
| `breathe` | Brightness swells between 55% and 100% |
| `pulse` | Brightness pulses between 10% and 100%, sharper than `breathe` |
| `spin` | The colors rotate around the middle |
| `ripple` | Rings of color move outward |

Other settings:
- `idleOffMinutes`: how long the "done" state stays lit; `0` keeps it on.
- `fps`: frames per second; takes effect when `cube.mjs` restarts.
- `port` and `musicPort`: the cube's port (55443) and the port it connects back to (54321), if you need to change them.

The animations are drawn around the middle of each cube, so they look the same however the cubes are stacked, and
every cube in a stack shows the same animation.

## Good to know

- **Logs:** `/tmp/claude-lamp/cube.log` records status changes, connections and errors.
- **Sessions that vanish** without ending (a crash, a closed terminal) stop counting after 2 hours without events.
- **If the cube is offline,** Claude isn't slowed down: the hook only writes a file. `cube.mjs` retries every
  10 seconds.
- **One machine drives the cube.** Each machine keeps its own session list, so set this up on the mini only.
- **At your other home** the cube isn't in sight; the Claude app's notifications on your phone cover that.

## What was checked

All of this ran against a stand-in cube that speaks the same protocol:
- **Commands:** the order (power on, per-LED mode, frame, music mode), the gradient's middle and edge colors, a
  three-cube frame of the right size, and a clean retry when the cube is unreachable.
- **Animations:** a 14-second run sent about 12 frames a second over music mode. The spin rotated the edges around a
  steady middle, the pulse swung from 19 to 183 brightness (out of 255), and the "done" state powered off on time. A
  color change in `cube.json` showed up within a second.
- **Hook:** a replay of two overlapping sessions (prompts, tool calls, a question, a permission prompt, finishing,
  ending) gave the right status after all 12 events.

Not yet tried on a real cube:
- The protocol comes from YeelightMatrix, which was written for the Cube Matrix; the Panel is its `5x5_blur` type.
- Whether the real cube connects back for music mode and keeps up with 12 frames a second.
- Whether the Yeelight app shows a LAN Control switch for the cube.
