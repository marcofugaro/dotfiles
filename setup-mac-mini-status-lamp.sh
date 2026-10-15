#!/bin/bash

# Stop the whole script on Ctrl+C, even when the interrupted command catches it
trap 'exit 130' INT

# Colors and headings for the output
source "$(dirname "$0")/utils/print.sh"

# Say so whenever sudo stops for the admin password
export SUDO_PROMPT="${bold}${yellow}Please enter your admin password, for sudo:${reset} "

# Yeelight Cube status lamp for the Mac mini: run from the admin account, after setup-mac-mini.sh.
# First put the cube on your Wi-Fi with a fixed address (yeelight-cube/README.md, step 1). Safe to run again.
#   ./setup-mac-mini-status-lamp.sh --update   re-allows Node through the firewall after brew upgrade moves it

# Run a command as agent, from / since it can't enter the private admin home
as_agent() {
  (cd / && sudo -H -u agent "$@")
}

# Let Node through the firewall, for the connection the cube opens back to animate
allow_node() {
  local node_bin
  node_bin="$(readlink -f "$(brew --prefix)/bin/node")"
  sudo /usr/libexec/ApplicationFirewall/socketfilterfw --add "$node_bin"
  sudo /usr/libexec/ApplicationFirewall/socketfilterfw --unblockapp "$node_bin"
}

if [[ "$1" == "--update" ]]; then
  section "Status lamp"
  allow_node
  exit
fi

title "Mac mini status lamp"


section "Node through the firewall"

allow_node


section "The lamp's files"

# Install the files in agent's ~/.claude, keeping its cube.json
lamp_dir=/Users/agent/.claude/yeelight-cube
sudo install -d -o agent -g staff "$lamp_dir"
sudo install -o agent -g staff -m 644 yeelight-cube/cube.mjs yeelight-cube/lamp-hook.sh yeelight-cube/cube.example.json "$lamp_dir/"
if [ ! -e "$lamp_dir/cube.json" ]; then
  prompt cube_ip "Please enter the cube's IP address:"
  sed "s/\"ip\": \"[^\"]*\"/\"ip\": \"$cube_ip\"/" yeelight-cube/cube.example.json | as_agent tee "$lamp_dir/cube.json" > /dev/null
  nc -z -w 3 "$cube_ip" 55443 && ok "The cube is reachable" || warn "Can't reach the cube: please check its address and LAN Control"
  ask "If it's more than one Panel, please list its modules in $lamp_dir/cube.json (yeelight-cube/README.md, step 3)"
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
# Reloaded every run, so a changed plist takes effect
sudo launchctl bootout system/local.claude-cube 2> /dev/null
sudo launchctl bootstrap system /Library/LaunchDaemons/local.claude-cube.plist


section "Claude Code hooks"

# Add the lamp's hooks to agent's Claude Code settings, next to any others
as_agent bash -c 'cd ~ && python3 -I -' <<'EOF'
import json, os

path = os.path.expanduser('~/.claude/settings.json')
settings = json.load(open(path)) if os.path.exists(path) else {}

def hook(state, matcher=None):
    entry = {'hooks': [{'type': 'command', 'command': f'bash ~/.claude/yeelight-cube/lamp-hook.sh {state}'}]}
    return {'matcher': matcher, **entry} if matcher else entry

lamp_hooks = {
    'SessionStart': hook('idle'),
    'UserPromptSubmit': hook('working'),
    'PreToolUse': hook('working', '*'),
    'PostToolUse': hook('working', '*'),
    'PermissionRequest': hook('input', '*'),
    'Notification': hook('input', 'permission_prompt|elicitation_dialog'),
    'Stop': hook('idle'),
    'SessionEnd': hook('off'),
}
hooks = settings.setdefault('hooks', {})
for event, entry in lamp_hooks.items():
    if entry not in hooks.setdefault(event, []):
        hooks[event].append(entry)

with open(path, 'w') as f:
    json.dump(settings, f, indent=2)
    f.write('\n')
EOF

echo
ok "Done"
ask "Please start a new Claude session as agent and send a prompt: the cube spins while Claude works."
