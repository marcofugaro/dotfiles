#!/bin/bash

# Stop the whole script on Ctrl+C, even when the interrupted command catches it
trap 'exit 130' INT

# Say so whenever sudo stops for the admin password
export SUDO_PROMPT='Waiting for your admin password, for sudo: '

# Ask for it once, and keep sudo from asking again while the script waits for you
sudo -v
while kill -0 "$$" 2> /dev/null; do sudo -n true; sleep 60; done 2> /dev/null &

# Mac mini setup: run at the mini itself, from the admin account, after setup.sh.
# Before running it, in the Tailscale admin console: save the access policy that owns tag:mini, and turn on
# MagicDNS and HTTPS certificates (README-mac-mini.md, step 5).
# At the end it turns FileVault off, then asks for Find My, the SSH keys, the Claude and GitHub logins and the repos,
# explaining each. Safe to run again: it skips what's done, so run it again to add keys or repos.
#   ./setup-mac-mini.sh --lock-ssh   allows only key logins from the tailnet, done for you once both users have a key
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
lock_ssh() {
  sudo tee /etc/ssh/sshd_config.d/000-hardening.conf > /dev/null <<EOF
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin no
AuthenticationMethods publickey
AllowUsers agent@100.64.0.0/10 agent@fd7a:115c:a1e0::/48 $(whoami)@100.64.0.0/10 $(whoami)@fd7a:115c:a1e0::/48
EOF
  sudo sshd -t && echo "SSH locked to keys and the tailnet: test it from a new connection before closing this one"
}

if [[ "$1" == "--lock-ssh" ]]; then
  lock_ssh
  exit
fi

# Install the Tailscale daemon that starts at boot, unless it's Homebrew's current one already: installing restarts
# Tailscale, which can drop SSH sessions over it for a moment
install_tailscaled() {
  [ -e /Library/LaunchDaemons/com.tailscale.tailscaled.plist ] &&
    cmp -s "$(brew --prefix)/bin/tailscaled" /usr/local/bin/tailscaled && return
  sudo tailscaled install-system-daemon
}

# Update, then re-allow Mosh and reinstall the Tailscale daemon, which brew upgrade leaves on the old version
# Restarting Tailscale can drop SSH sessions over it for a moment, so run it in tmux
if [[ "$1" == "--update" ]]; then
  brew update && brew upgrade
  allow_mosh
  install_tailscaled
  [ -e /Library/LaunchDaemons/local.claude-cube.plist ] && ./setup-mac-mini-status-lamp.sh --update
  exit
fi

# Run a command as agent, from / since it can't enter the private admin home
as_agent() {
  (cd / && sudo -H -u agent "$@")
}

# The mini's MagicDNS name, like mini.<tailnet>.ts.net
tailnet_host() {
  tailscale status --json 2> /dev/null | python3 -c 'import json, sys; print(json.load(sys.stdin)["Self"]["DNSName"].rstrip("."))' 2> /dev/null || echo 'mini.<tailnet>.ts.net'
}

# Show what to do by hand, then wait for Enter
wait_for() {
  echo
  echo "$1"
  read -r -p "Waiting for you: press Enter when done. "
}

# Add a public key to both users' authorized_keys, once
add_key() {
  ssh-keygen -l -f /dev/stdin <<< "$1" &> /dev/null || { echo "That's not a public key, skipped"; return; }
  for user in "$(whoami)" agent; do
    (cd / && sudo -H -u "$user" bash -c 'mkdir -p ~/.ssh && chmod 700 ~/.ssh && touch ~/.ssh/authorized_keys &&
      chmod 600 ~/.ssh/authorized_keys && { grep -qxF "$1" ~/.ssh/authorized_keys || echo "$1" >> ~/.ssh/authorized_keys; }' _ "$1")
  done
  echo "Added for $(whoami) and agent"
}

# Clone a repo for agent into ~/Code and install it
add_repo() {
  as_agent zsh -lc '
    cd ~/Code || exit 1
    name="${1##*/}"
    [ -d "$name" ] || gh repo clone "$1" || exit 1
    cd "$name"
    [ ! -e package-lock.json ] || npm ci
  ' _ "$1"
}

# Name the machine
sudo scutil --set ComputerName mini
sudo scutil --set HostName mini
sudo scutil --set LocalHostName mini

# Never sleep, wake on network access, start up whenever power returns
sudo pmset -a sleep 0 disksleep 0 womp 1 autorestart 1 autorestartatconnect 1

# Wi-Fi on even with Ethernet, since Find My locates the mini from the networks around it
wifi="$(networksetup -listallhardwareports | awk '/Wi-Fi/ { getline; print $2 }')"
[ -n "$wifi" ] && sudo networksetup -setairportpower "$wifi" on

# Firewall with stealth mode, the built-in SSH server stays allowed
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setstealthmode on

# Make the admin home folder private
sudo chmod 700 "$HOME"

# Set the Dock apps, after Finder
dock_item() {
  printf '<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>%s</string><key>_CFURLStringType</key><integer>0</integer></dict></dict></dict>' "$1"
}
defaults write com.apple.dock persistent-apps -array \
  "$(dock_item /System/Applications/Utilities/Terminal.app)" \
  "$(dock_item /System/Applications/System\ Settings.app)"
killall Dock

# Install tmux, Mosh and the Tailscale daemon
brew install tmux mosh tailscale

# Install applications
brew install --cask blender

allow_mosh

# Start Tailscale at boot, then approve the device from the link it prints, unless it's connected already
install_tailscaled
if ! tailscale status &> /dev/null; then
  echo "Waiting for you to approve the mini: open the link Tailscale prints, signed in as the tailnet's owner"
  if ! sudo tailscale up --hostname=mini --advertise-tags=tag:mini; then
    cat <<'EOF'

Tailscale refused the login. If it says tag:mini is invalid or not permitted, save the access policy with
"tagOwners": { "tag:mini": ["autogroup:owner", "autogroup:admin"] } in the admin console (README-mac-mini.md,
step 5), approve the link signed in as the tailnet's owner or an admin, then run this script again.
EOF
    exit 1
  fi
fi

# Publish the dev servers on ports 5173–5180, one per repo, to the tailnet only, each at https://<mini>:<port>
for port in {5173..5180}; do
  sudo tailscale serve --bg --https="$port" "$port"
done

# This machine's rules for Claude Code, with its tailnet address
mini_host="$(tailnet_host)"
claude_md="$(cat CLAUDE.md; echo; sed "s/mini\.<tailnet>\.ts\.net/$mini_host/" CLAUDE-mac-mini.md)"
printf "%s\n" "$claude_md" > ~/.claude/CLAUDE.md


###############################################################################
# The agent user, a standard user that runs Claude                            #
###############################################################################

# Create it, asking for its password
if ! id agent &> /dev/null; then
  echo "Waiting for a password for the new agent user"
  sudo sysadminctl -addUser agent -fullName agent -password -
fi
sudo createhomedir -c -u agent > /dev/null

# Remote Login for only you and agent: the access group is what "Only these users" lists
sudo dseditgroup -o read com.apple.access_ssh &> /dev/null || sudo dseditgroup -o create -q com.apple.access_ssh
sudo dseditgroup -o edit -a "$(whoami)" -t user com.apple.access_ssh
sudo dseditgroup -o edit -a agent -t user com.apple.access_ssh
sudo launchctl enable system/com.openssh.sshd
sudo launchctl print system/com.openssh.sshd &> /dev/null || sudo launchctl bootstrap system /System/Library/LaunchDaemons/ssh.plist

# Install Claude Code in its home, where it updates itself
as_agent test -x /Users/agent/.local/bin/claude || as_agent bash -c 'cd ~ && curl -fsSL https://claude.ai/install.sh | bash'

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

# Starts Claude and the dev servers in tmux unless they're running, launchd runs it at boot and every 5 minutes
as_agent mkdir -p /Users/agent/Code
as_agent tee /Users/agent/mini-up.sh > /dev/null <<'EOF'
#!/bin/zsh -l
# Starts the main Claude session in tmux, and each repo's dev server in a window named after it, unless running.
# launchd runs it at boot and every 5 minutes; you can also run it yourself: zsh -l ~/mini-up.sh
cd ~/Code || exit 1

# After a power cut the router can take minutes to come back, and Claude needs the internet
until curl -sS -m 5 -o /dev/null https://api.anthropic.com; do
  sleep 10
done

# Open a window in the main session, unless one with that name is there
start() {
  if ! tmux has-session -t main 2>/dev/null; then
    tmux new-session -d -s main -n "$1" -c "$2" "$3"
  elif ! tmux list-windows -t main -F '#W' | grep -qxF "$1"; then
    tmux new-window -d -t main -n "$1" -c "$2" "$3"
  fi
}

start claude ~/Code "$HOME/.local/bin/claude -n main"
for dir in ~/Code/*(/N); do
  if grep -q '"dev":' "$dir/package.json" 2>/dev/null; then
    start "${dir:t}" "$dir" "npm run dev"
  fi
done
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
  "permissions": { "defaultMode": "auto" },
  "worktree": { "bgIsolation": "none" }
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

# Run mini-up.sh as agent at every boot and every 5 minutes, so what stops comes back
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
  <key>StartInterval</key>
  <integer>300</integer>
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
# Reloaded every run, so a changed plist takes effect; tmux keeps running
sudo launchctl bootout system/local.mini-up 2> /dev/null
sudo launchctl bootstrap system /Library/LaunchDaemons/local.mini-up.plist


###############################################################################
# Keys and logins, which only you can provide                                 #
###############################################################################

# FileVault off, so the mini comes back by itself after a power cut instead of waiting at the unlock screen
if fdesetup isactive &> /dev/null; then
  echo
  echo "Turning FileVault off. Waiting for your user name and password:"
  sudo fdesetup disable
fi

# Find My, to locate, lock or erase a stolen mini. The Apple Account sign-in has no command, so open its settings
# and carry on once Find My is on; macos.sh turns on Location Services
if ! nvram fmm-mobileme-token-FMM &> /dev/null; then
  open "x-apple.systempreferences:com.apple.systempreferences.AppleIDSettings"
  cat <<'EOF'

Find My, in the System Settings window that just opened:
1. Sign in with your Apple Account, then turn off what iCloud syncs: the mini only needs Find My
2. iCloud → Find My Mac: turn it on, and allow it the mini's location if it asks
EOF
  echo "Waiting for Find My Mac to turn on, or press Enter to skip"
  until nvram fmm-mobileme-token-FMM &> /dev/null || read -r -t 5; do :; done
  if nvram fmm-mobileme-token-FMM &> /dev/null; then
    echo "Find My is on: check from your phone at icloud.com/find that the mini is on the map"
  else
    echo "Find My skipped: run this script again to turn it on"
  fi
fi

# SSH keys for both users, then SSH locked to them
cat <<EOF

Waiting for the SSH keys of the MacBook and the phone, for both your account and agent. Until you press Enter, SSH
also takes passwords, which is how the keys get here:
- MacBook: in the dotfiles folder, run ./setup-macbook.sh again, which sends its key
- Phone: in Termius, Keychain → + → Generate key, type ed25519, with a passphrase. Add the mini as a host at
  $mini_host, then open the key → Export to host, once as $(whoami) and once as agent.
Or paste public keys here, one per line. Press Enter on an empty line when they're in: SSH then takes keys only.
EOF
while read -r -p "> " key && [ -n "$key" ]; do
  add_key "$key"
done

# Locked once both users have a key, unless it is already
if [ ! -e /etc/ssh/sshd_config.d/000-hardening.conf ]; then
  if [ -s ~/.ssh/authorized_keys ] && sudo test -s /Users/agent/.ssh/authorized_keys; then
    lock_ssh
    wait_for "Test SSH, now limited to keys and the tailnet:
- MacBook: ssh mini 'echo key login works', then ssh -o PubkeyAuthentication=no mini, which must fail with \"Permission denied\"
- Phone: in Termius, add a host with address $mini_host, user agent and the key you made, then connect
If a test fails, run sudo rm /etc/ssh/sshd_config.d/000-hardening.conf to allow passwords again, and check the keys."
  else
    echo "SSH stays open to passwords until both users have a key: run this script again to add them"
  fi
fi

# Claude login for agent
if ! as_agent zsh -lc '~/.local/bin/claude auth status' &> /dev/null; then
  echo
  echo "Waiting for the Claude login for agent: open the link it prints, approve with your claude.ai account, and paste the code back here."
  as_agent zsh -lc 'cd ~ && ~/.local/bin/claude auth login'
  # The boot job may have started Claude before the login, restart it logged in
  as_agent zsh -lc 'tmux respawn-window -k -t main:claude' 2> /dev/null
fi

# GitHub login for agent, with a token of its own
if ! as_agent zsh -lc 'gh auth status' &> /dev/null; then
  cat <<'EOF'

GitHub for agent, with a token of its own:
1. On github.com: Settings → Developer settings → Personal access tokens → Fine-grained tokens → Generate new token
2. Expiration: 90 days. Repository access: only the repos the mini works on.
3. Permissions → Repository permissions: Contents read and write, Pull requests read and write
4. Generate it and copy the token
EOF
  read -r -s -p "Waiting for the token, paste it (hidden): " token
  echo
  printf '%s\n' "$token" | as_agent zsh -lc 'gh auth login --with-token'
  unset token
fi
# Git over HTTPS with that login, set again each run since the dotfiles above replace ~/.gitconfig
as_agent zsh -lc 'gh auth status &> /dev/null && gh auth setup-git'

# The repos, each with its dev server running
echo
read -r -p "Waiting for the repos to clone into agent's ~/Code, space-separated (name or owner/name), empty to skip: " repos
for repo in $repos; do
  add_repo "$repo"
done
if [ -n "$repos" ]; then
  as_agent zsh -l /Users/agent/mini-up.sh
  echo "Their dev servers are running, each in the tmux window named after its repo"
fi

cat <<'EOF'

Done. What's left is in README-mac-mini.md: pin each repo's dev server port in its Vite config (step 8), bring your
Claude memory over from the MacBook (step 9), and check the boot job with a power cut (step 10).
EOF
