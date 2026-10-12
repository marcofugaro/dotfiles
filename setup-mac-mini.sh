#!/bin/bash

# Mac mini setup: run from the admin account, after setup.sh.
# Before running it, in the Tailscale admin console: save the access policy that owns tag:mini, and turn on
# MagicDNS and HTTPS certificates (README-mac-mini.md, step 5).
# Afterwards:
#   ./setup-mac-mini.sh --lock-ssh   once the SSH keys are added, allows only key logins from the tailnet
#   ./setup-mac-mini.sh --update     updates Homebrew packages and refreshes what they leave behind
# The other manual steps are in README-mac-mini.md.

# Let Mosh through the firewall, by the path of its current version
allow_mosh() {
  local mosh_server
  mosh_server="$(readlink -f "$(brew --prefix)/bin/mosh-server")"
  sudo /usr/libexec/ApplicationFirewall/socketfilterfw --add "$mosh_server"
  sudo /usr/libexec/ApplicationFirewall/socketfilterfw --unblockapp "$mosh_server"
}

# SSH with keys only, from the tailnet only
if [[ "$1" == "--lock-ssh" ]]; then
  sudo tee /etc/ssh/sshd_config.d/000-hardening.conf > /dev/null <<EOF
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin no
AuthenticationMethods publickey
AllowUsers agent@100.64.0.0/10 agent@fd7a:115c:a1e0::/48 $(whoami)@100.64.0.0/10 $(whoami)@fd7a:115c:a1e0::/48
EOF
  sudo sshd -t && echo "SSH config OK, test it from a new connection before closing this one"
  exit
fi

# Update, then re-allow Mosh and reinstall the Tailscale daemon, which brew upgrade leaves on the old version
# Restarting Tailscale can drop SSH sessions over it for a moment, so run it in tmux
if [[ "$1" == "--update" ]]; then
  brew update && brew upgrade
  allow_mosh
  sudo tailscaled install-system-daemon
  [ -e /Library/LaunchDaemons/local.claude-cube.plist ] && ./setup-mac-mini-status-lamp.sh --update
  exit
fi

# Run a command as agent, in its own home
as_agent() {
  sudo -H -u agent "$@"
}

# Name the machine
sudo scutil --set ComputerName mini
sudo scutil --set HostName mini
sudo scutil --set LocalHostName mini

# Never sleep, wake on network access, restart after a power cut
sudo pmset -a sleep 0 disksleep 0 womp 1 autorestart 1

# Firewall with stealth mode, the built-in SSH server stays allowed
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setstealthmode on

# Make the admin home folder private
sudo chmod 700 "$HOME"

# Install tmux, Mosh and the Tailscale daemon
brew install tmux mosh tailscale

# Install applications
brew install --cask blender

allow_mosh

# Start Tailscale at boot, then approve the device from the link it prints
sudo tailscaled install-system-daemon
sudo tailscale up --hostname=mini --advertise-tags=tag:mini

# Publish the dev servers on ports 5173–5180, one per repo, to the tailnet only, each at https://<mini>:<port>
for port in {5173..5180}; do
  sudo tailscale serve --bg --https="$port" "$port"
done

# This machine's rules for Claude Code, with its tailnet address
mini_host="$(tailscale status --json 2> /dev/null | python3 -c 'import json, sys; print(json.load(sys.stdin)["Self"]["DNSName"].rstrip("."))' 2> /dev/null)"
[ -n "$mini_host" ] || mini_host='mini.<tailnet>.ts.net'
claude_md="$(cat CLAUDE.md; echo; sed "s/mini\.<tailnet>\.ts\.net/$mini_host/" CLAUDE-mac-mini.md)"
printf "%s\n" "$claude_md" > ~/.claude/CLAUDE.md


###############################################################################
# The agent user, a standard user that runs Claude                            #
###############################################################################

# Create it, asking for its password
id agent &>/dev/null || sudo sysadminctl -addUser agent -fullName agent -password -
sudo createhomedir -c -u agent > /dev/null

# Allow it to log in over SSH
sudo dseditgroup -o edit -a agent -t user com.apple.access_ssh

# Install Claude Code in its home, where it updates itself
as_agent bash -c 'cd ~ && curl -fsSL https://claude.ai/install.sh | bash'

# The same dotfiles as the admin
for file in .zshrc .vimrc .gitconfig .gitignore; do
  sudo install -o agent -g staff -m 644 "$file" /Users/agent/
done
[ -d /Users/agent/.zsh/zsh-shift-select ] || as_agent bash -c 'cd ~ && git clone --depth 1 https://github.com/jirutka/zsh-shift-select.git ~/.zsh/zsh-shift-select'

# For login shells, launchd's included: Homebrew on the path, and Vite answering on the tailnet address
as_agent tee /Users/agent/.zprofile > /dev/null <<EOF
eval "\$(/opt/homebrew/bin/brew shellenv)"
export __VITE_ADDITIONAL_SERVER_ALLOWED_HOSTS='$mini_host'
EOF

# Land in the tmux session on every SSH login
as_agent tee -a /Users/agent/.zshrc > /dev/null <<'EOF'

# attach to the main tmux session on SSH logins, except from VS Code
if [[ -n "$SSH_CONNECTION" && -z "$TMUX" && "$TERM_PROGRAM" != "vscode" && $- == *i* ]]; then
  tmux new-session -A -s main
fi
EOF

as_agent tee /Users/agent/.tmux.conf > /dev/null <<'EOF'
set -g mouse on
set -g history-limit 100000
EOF

# Starts Claude in tmux unless it's running, launchd runs it at boot
as_agent mkdir -p /Users/agent/Code
as_agent tee /Users/agent/mini-up.sh > /dev/null <<'EOF'
#!/bin/zsh -l
# Starts the main Claude session in tmux, unless it's already running.
# launchd runs it at boot; after a restart you can also run it yourself: zsh -l ~/mini-up.sh
cd ~/Code || exit 1
tmux has-session -t main 2>/dev/null && exit 0

# At boot the network can take a moment to come up, and Claude needs it
for i in {1..24}; do
  curl -sS -m 5 -o /dev/null https://api.anthropic.com && break
  sleep 5
done

tmux new-session -d -s main -n claude -c "$PWD" "$HOME/.local/bin/claude -n main"
EOF

# Claude Code settings and instructions
as_agent mkdir -p /Users/agent/.claude
[ -e /Users/agent/.claude/settings.json ] || as_agent tee /Users/agent/.claude/settings.json > /dev/null <<'EOF'
{
  "remoteControlAtStartup": true,
  "inputNeededNotifEnabled": true,
  "agentPushNotifEnabled": true,
  "dialogExpiry": "never",
  "modelSettings": { "claude-opus-5-5": { "effortLevel": "xhigh" } },
  "permissions": { "defaultMode": "auto" }
}
EOF
printf "%s\n" "$claude_md" | as_agent tee /Users/agent/.claude/CLAUDE.md > /dev/null


###############################################################################
# Machine-wide                                                                #
###############################################################################

# Claude Code rules agent can't loosen
sudo mkdir -p "/Library/Application Support/ClaudeCode"
sudo tee "/Library/Application Support/ClaudeCode/managed-settings.json" > /dev/null <<'EOF'
{
  "permissions": {
    "disableBypassPermissionsMode": "disable",
    "deny": ["Read(~/.ssh/**)", "Read(~/.config/gh/**)", "Read(~/.claude/.credentials.json)"],
    "ask": ["Bash(git push *)"]
  }
}
EOF
sudo chown root:wheel "/Library/Application Support/ClaudeCode/managed-settings.json"
sudo chmod 644 "/Library/Application Support/ClaudeCode/managed-settings.json"

# Run mini-up.sh as agent at every boot
sudo tee /Library/LaunchDaemons/local.mini-up.plist > /dev/null <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>local.mini-up</string>
  <key>UserName</key>
  <string>agent</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/zsh</string>
    <string>-l</string>
    <string>/Users/agent/mini-up.sh</string>
  </array>
  <key>EnvironmentVariables</key>
  <dict>
    <key>HOME</key>
    <string>/Users/agent</string>
    <key>LANG</key>
    <string>en_US.UTF-8</string>
    <key>TERM</key>
    <string>xterm-256color</string>
  </dict>
  <key>RunAtLoad</key>
  <true/>
  <key>AbandonProcessGroup</key>
  <true/>
  <key>StandardOutPath</key>
  <string>/tmp/mini-up.log</string>
  <key>StandardErrorPath</key>
  <string>/tmp/mini-up.log</string>
</dict>
</plist>
EOF
sudo chown root:wheel /Library/LaunchDaemons/local.mini-up.plist
sudo chmod 644 /Library/LaunchDaemons/local.mini-up.plist
sudo launchctl print system/local.mini-up &> /dev/null || sudo launchctl bootstrap system /Library/LaunchDaemons/local.mini-up.plist

cat <<'EOF'

Done. Still to do by hand (README-mac-mini.md):
1. Turn on Remote Login, for "Only these users" (step 2)
2. Add the SSH keys from the MacBook and the phone to both users (step 6)
3. Lock SSH to keys and the tailnet: ./setup-mac-mini.sh --lock-ssh
4. Log in to Claude as agent: ssh mini, then claude auth login (step 9)
5. Log in to GitHub as agent with its token, clone your repos, and start their dev servers (steps 7, 8 and 10)
EOF
