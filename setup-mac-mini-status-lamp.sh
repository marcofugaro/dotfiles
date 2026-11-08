#!/bin/bash

# Stop the whole script on Ctrl+C, even when the interrupted command catches it
trap 'exit 130' INT

# Colors and headings for the output
source "$(dirname "$0")/utils/print.sh"

# Say so whenever sudo stops for the admin password
export SUDO_PROMPT="${bold}${yellow}Please enter your admin password, for sudo:${reset} "

# Yeelight Cube status lamp for the Mac mini: run from the admin account, after setup-mac-mini.sh.
# First put the cube on your Wi-Fi with a fixed address (yeelight-cube/README.md, step 1). Safe to run again: it installs
# the lamp's files and settings again, keeping the cube's address and cubes.
#   ./setup-mac-mini-status-lamp.sh --update   lets the new Node through the firewall, run by setup-mac-mini.sh --update

lamp_dir=/Users/agent/.claude/yeelight-cube

# Run a command as agent, from / since it can't enter the private admin home
as_agent() {
  (cd / && sudo -H -u agent "$@")
}

# Let Node through the firewall, by the path of its current version, for the connection the cube opens back to animate
allow_node() {
  local node_bin
  node_bin="$(readlink -f "$(brew --prefix)/bin/node")"
  sudo /usr/libexec/ApplicationFirewall/socketfilterfw --add "$node_bin"
  sudo /usr/libexec/ApplicationFirewall/socketfilterfw --unblockapp "$node_bin"
}

# After brew upgrade: the new Node through the firewall, and the lamp restarted on it
if [[ "$1" == "--update" ]]; then
  section "Status lamp"
  allow_node
  sudo launchctl kickstart -k system/local.claude-cube
  exit
fi

title "Mac mini status lamp"

# Ask for it once, and keep sudo from asking again while the script waits for you
sudo -v
while kill -0 "$$" 2> /dev/null; do sudo -n true; sleep 60; done 2> /dev/null &


section "Node through the firewall"

allow_node


section "The lamp's files"

# Install the files in agent's ~/.claude
as_agent mkdir -p "$lamp_dir"
sudo install -o agent -g staff -m 644 yeelight-cube/cube.mjs yeelight-cube/lamp-hook.sh yeelight-cube/cube.example.json "$lamp_dir/"

# The cube's settings, from cube.example.json. Its address and its cubes from the base up come from the current
# settings, or are asked the first time.
if as_agent test -e "$lamp_dir/cube.json"; then
  cube_ip="$(as_agent plutil -extract ip raw -o - "$lamp_dir/cube.json")"
  modules="$(as_agent plutil -extract modules json -o - "$lamp_dir/cube.json" | sed -e 's/^\[//' -e 's/]$//' -e 's/,/, /g')"
fi
until [[ "$cube_ip" =~ ^[0-9]+(\.[0-9]+){3}$ ]]; do
  prompt cube_ip "Please enter the cube's IP address, or press Enter for 192.168.1.63:"
  cube_ip="${cube_ip:-192.168.1.63}"
done
until [ -n "$modules" ]; do
  prompt cube_modules "Please list its cubes from the base up, 5x5_blur (Panel), 5x5_clear (Matrix) or 1x1 (Spot), or press Enter for one Panel:"
  for module in ${cube_modules:-5x5_blur}; do
    case "$module" in
      5x5_blur | 5x5_clear | 1x1) modules+="${modules:+, }\"$module\"" ;;
      *) warn "$module isn't a cube type"; modules=""; break ;;
    esac
  done
done
sed -e "s/\"ip\": \"[^\"]*\"/\"ip\": \"$cube_ip\"/" -e "s/\"modules\": \[[^]]*]/\"modules\": [$modules]/" \
  yeelight-cube/cube.example.json | as_agent tee "$lamp_dir/cube.json" > /dev/null

# Check the cube answers at the address in its settings
cube_ip="$(as_agent plutil -extract ip raw -o - "$lamp_dir/cube.json")"
if nc -z -G 3 "$cube_ip" 55443 &> /dev/null; then
  ok "The cube answers at $cube_ip"
else
  warn "The cube doesn't answer at $cube_ip: please check LAN Control in the Yeelight app, and the address in $lamp_dir/cube.json"
fi


section "Boot job"

# Run cube.mjs as agent at every boot, restarted if it stops
sudo tee /Library/LaunchDaemons/local.claude-cube.plist > /dev/null <<'EOF'
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
# Reloaded every run, so a changed plist or cube.mjs takes effect
sudo launchctl bootout system/local.claude-cube 2> /dev/null
sudo launchctl bootstrap system /Library/LaunchDaemons/local.claude-cube.plist


section "Claude Code hooks"

# The lamp's hooks in agent's Claude Code settings, replacing an earlier run's and keeping the others
as_agent python3 -I - <<'PY'
import json, os

path = '/Users/agent/.claude/settings.json'
settings = json.load(open(path)) if os.path.exists(path) else {}

def hook(state, matcher=None):
    entry = {'hooks': [{'type': 'command', 'command': f'bash ~/.claude/yeelight-cube/lamp-hook.sh {state}'}]}
    return {'matcher': matcher, **entry} if matcher else entry

def is_lamp(entry):
    return any('lamp-hook.sh' in h.get('command', '') for h in entry.get('hooks', []))

lamp_hooks = {
    'SessionStart': hook('idle'),
    'UserPromptSubmit': hook('working'),
    'PreToolUse': hook('working', '*'),
    'PostToolUse': hook('working', '*'),
    'PostToolUseFailure': hook('working', '*'),
    'PermissionRequest': hook('input', '*'),
    'Notification': hook('input', 'permission_prompt|elicitation_dialog'),
    'SubagentStart': hook('working'),
    'SubagentStop': hook('off'),
    'Stop': hook('idle'),
    'SessionEnd': hook('off'),
}

hooks = settings.setdefault('hooks', {})
for event in list(hooks):
    hooks[event] = [entry for entry in hooks[event] if not is_lamp(entry)]
    if not hooks[event]:
        del hooks[event]
for event, entry in lamp_hooks.items():
    hooks.setdefault(event, []).append(entry)

with open(path, 'w') as f:
    json.dump(settings, f, indent=2, ensure_ascii=False)
    f.write('\n')
PY

echo
ok "Done"
ask "Please start a new Claude chat as agent, with Ctrl-n in tmux, and send a prompt: the cube spins while Claude works."
