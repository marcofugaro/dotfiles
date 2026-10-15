#!/bin/bash

# Stop the whole script on Ctrl+C, even when the interrupted command catches it
trap 'exit 130' INT

# Colors and headings for the output
source "$(dirname "$0")/utils/print.sh"

# Say so whenever sudo stops for the admin password
export SUDO_PROMPT="${bold}${yellow}Please enter your admin password, for sudo:${reset} "

# Mac mini setup: run at the mini itself, from the admin account, after setup.sh.
# Before running it, in the Tailscale admin console: save the access policy that owns tag:mini, and turn on
# MagicDNS and HTTPS certificates (README-mac-mini.md, step 5).
# At the end it turns FileVault off, then asks for Find My, the phone on Tailscale, the SSH keys, the Claude and
# GitHub logins and the repos, explaining each. Safe to run again: it skips what's done, so run it again to add keys
# or repos.
#   ./setup-mac-mini.sh --lock-ssh   allows only key logins from the tailnet, done for you once both users have a key
#   ./setup-mac-mini.sh --update     updates Homebrew packages and refreshes what they leave behind
# The other manual steps are in README-mac-mini.md.
title "Mac mini setup"

# Ask for it once, and keep sudo from asking again while the script waits for you
sudo -v
while kill -0 "$$" 2> /dev/null; do sudo -n true; sleep 60; done 2> /dev/null &

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
  sudo sshd -t && ok "SSH locked to keys and the tailnet: please test it from a new connection before closing this one"
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
  section "Homebrew update"
  brew update && brew upgrade
  section "Mosh and Tailscale"
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

# Whether a phone is on the tailnet, which Termius needs to reach the mini
phone_on_tailnet() {
  tailscale status --json 2> /dev/null | python3 -c '
import json, sys
peers = (json.load(sys.stdin).get("Peer") or {}).values()
sys.exit(not any(p.get("OS") in ("android", "iOS") for p in peers))' 2> /dev/null
}

# Show what to do by hand, then the details, then wait for Enter
wait_for() {
  echo
  ask "$1"
  echo "$2"
  prompt REPLY "Please press Enter when done."
}

# Add a public key to both users' authorized_keys, once
add_key() {
  ssh-keygen -l -f /dev/stdin <<< "$1" &> /dev/null || { warn "That's not a public key, skipped"; return; }
  for user in "$(whoami)" agent; do
    (cd / && sudo -H -u "$user" bash -c 'mkdir -p ~/.ssh && chmod 700 ~/.ssh && touch ~/.ssh/authorized_keys &&
      chmod 600 ~/.ssh/authorized_keys && { grep -qxF "$1" ~/.ssh/authorized_keys || echo "$1" >> ~/.ssh/authorized_keys; }' _ "$1")
  done
  ok "Added for $(whoami) and agent"
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

# Install Homebrew packages, unless installed already: --update upgrades them
brew_install() {
  for package in "$@"; do
    brew list "$package" &> /dev/null || brew install "$package"
  done
}

# Install an application, unless it's in /Applications already, from Homebrew or not
install_app() {
  [ -e "/Applications/$2.app" ] || brew install --cask "$1"
}


section "System settings"

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


section "Packages and apps"

# Install tmux, Mosh and the Tailscale daemon
brew_install tmux mosh tailscale

# Install applications
install_app blender Blender

allow_mosh


section "Tailscale"

# Start Tailscale at boot, then approve the device from the link it prints, unless it's connected already
install_tailscaled
if ! tailscale status &> /dev/null; then
  ask "Please approve the mini: open the link Tailscale prints, signed in as the tailnet's owner"
  if ! sudo tailscale up --hostname=mini --advertise-tags=tag:mini; then
    echo
    fail "Tailscale refused the login."
    cat <<'EOF'
If it says tag:mini is invalid or not permitted, please save the access policy with
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


section "Claude Code instructions"

# This machine's rules for Claude Code, with its tailnet address
mini_host="$(tailnet_host)"
claude_md="$(cat CLAUDE.md; echo; sed "s/mini\.<tailnet>\.ts\.net/$mini_host/" CLAUDE-mac-mini.md)"
printf "%s\n" "$claude_md" > ~/.claude/CLAUDE.md


###############################################################################
# The agent user, a standard user that runs Claude                            #
###############################################################################

section "The agent user"

# Create it, asking for its password
if ! id agent &> /dev/null; then
  ask "Please choose a password for the new agent user: you'll need it again for the MacBook's and the phone's SSH keys"
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

# For every other shell too, like the one SSH runs a command in, which is how Mosh starts its server
as_agent tee /Users/agent/.zshenv > /dev/null <<'EOF'
typeset -U PATH path
path=(/opt/homebrew/bin $path)

# a Mosh server whose device went away quits after a day, which closes its tmux view
export MOSH_SERVER_NETWORK_TMOUT=86400
EOF

# On every SSH login, a view of the tmux session of its own: devices share the windows, each picks its own
as_agent tee -a /Users/agent/.zshrc > /dev/null <<'EOF'

# open a view of the main tmux session's windows, for this terminal only, on the main chat; it goes away when it
# detaches
chats() {
  if ! tmux has-session -t '=main' 2> /dev/null; then
    if tmux list-sessions -F '#{session_group}' 2> /dev/null | grep -qxF main; then
      # main was closed while a view kept its windows: it takes them back
      tmux new-session -d -s main -t main -c ~/Code 2> /dev/null
    else
      tmux new-session -d -s main -n claude -c ~/Code "$HOME/.local/bin/claude -n main"
    fi
  fi
  tmux new-session -t '=main' -c ~/Code \; set-option destroy-unattached keep-last \; select-window -t '=claude'
}

# on SSH logins, except from VS Code, whose terminals run `chats` by hand
if [[ -n "$SSH_CONNECTION" && -z "$TMUX" && "$TERM_PROGRAM" != "vscode" && $- == *i* ]]; then
  chats
fi
EOF

as_agent tee /Users/agent/.tmux.conf > /dev/null <<'EOF'
set -g mouse on
set -g history-limit 100000

# Window names stay as given, instead of following the program running in them
set -g automatic-rename off

# The terminal's tab title: user@host and the window, like agent@mini: fix-login
set -g set-titles on
set -g set-titles-string '#{user}@#{host_short}: #W'

# A chat that needs you rings the bell: its tab turns red with a !, with a message instead of a sound
set -g visual-bell on

# The status line is a row of tabs, in fixed colors that read in any terminal theme: the current tab white, one that
# needs you red. Spacing is on a 4px scale, as near as cells allow: 2 cells (16px) each side of the name, 1 cell (8px)
# between tabs and at the edges, and a blank row (16px) above and below
set -g status 3
set -g message-line 1
set -g status-style 'bg=default,fg=colour250'
set -g window-status-style 'bg=colour238,fg=colour252'
set -g window-status-current-style 'bg=colour255,fg=colour16,bold'
set -g window-status-bell-style 'bg=colour203,fg=colour16,bold'
set -g window-status-format '  #W#{?window_bell_flag,!,}  '
set -g window-status-current-format '  #W  '

# On the right the clock, or on a narrow screen a ! for each window that needs you
set -g status-right '#{?#{e|<:#{client_width},80},#{W:#{?window_bell_flag,!,}},%H:%M} '

# The names in the middle row. The blank rows above and below carry the tabs' ranges at the same widths, so a tap
# there opens the tab it touches, three rows tall to hit on the phone
%hidden TAB='#[range=window|#{window_index} #{?window_bell_flag,#{E:window-status-bell-style},#{E:window-status-style}}]'
%hidden CURRENT='#[range=window|#{window_index} list=focus #{E:window-status-current-style}]'
%hidden END='#[norange list=on default]#{?loop_last_flag,,#{E:window-status-separator}}'
%hidden BLANK="#[align=left] #[list=on]#[list=left-marker] #[list=right-marker] #[list=on]#{W:#[range=window|#{window_index}]#{R: ,#{w;T:window-status-format}}$END,#[range=window|#{window_index} list=focus]#{R: ,#{w;T:window-status-current-format}}$END}#[nolist align=right]#{R: ,#{w;T:status-right}}"
set -g status-format[0] "$BLANK"
set -g status-format[1] "#[align=left] #[list=on]#[list=left-marker]<#[list=right-marker]>#[list=on]#{W:$TAB#{T:window-status-format}$END,$CURRENT#{T:window-status-current-format}$END}#[nolist align=right]#{T:status-right}"
set -g status-format[2] "$BLANK"

# The keys used most are Ctrl and a letter, without Ctrl-b, so the programs in the windows never get them

# Ctrl-n: a new Claude chat in a window of its own, asking for a folder in ~/Code and a name
bind-key -N "New Claude chat in its own window" -n C-n command-prompt -p "repo in ~/Code:,chat name:" {
  if-shell "test -n '%2' && test -d ~/Code/'%1'" {
    new-window -S -n "%2" -c "~/Code/%1" "~/.local/bin/claude -n '%2'"
  } {
    display-message -d 5000 "No chat opened: it needs a name and a folder in ~/Code"
  }
}

# Ctrl-t: a new shell, like Ctrl-b c
bind-key -N "New shell" -n C-t new-window

# Ctrl-w and Ctrl-b w: the window list, picking within this device's view
bind-key -N "Choose a window" -n C-w choose-tree -Zw "select-window -t '%%'"
bind-key -N "Choose a window" w choose-tree -Zw "select-window -t '%%'"

# Ctrl-a: the next window with a !
bind-key -N "Next window with an alert" -n C-a next-window -a

# Ctrl-f: fit the window to this device, like Ctrl-b r
bind-key -N "Fit the window to this device" -n C-f refresh-client
EOF

# A running tmux reads its config only when it starts
as_agent zsh -lc 'tmux source-file ~/.tmux.conf' &> /dev/null

# Starts Claude and the dev servers in tmux unless they're running, launchd runs it at boot and every 5 minutes
as_agent mkdir -p /Users/agent/Code
as_agent tee /Users/agent/mini-up.sh > /dev/null <<'EOF'
#!/bin/zsh -l
# Starts the main chat in tmux, and each repo's dev server in a window named after it, unless running.
# launchd runs it at boot and every 5 minutes; you can also run it yourself: zsh -l ~/mini-up.sh
cd ~/Code || exit 1

# After a power cut the router can take minutes to come back, and Claude needs the internet
until curl -sS -m 5 -o /dev/null https://api.anthropic.com; do
  sleep 10
done

# Open a window in the main session, unless one with that name is there
start() {
  # main was closed while a view kept its windows: it takes them back
  if ! tmux has-session -t '=main' 2>/dev/null &&
    tmux list-sessions -F '#{session_group}' 2>/dev/null | grep -qxF main; then
    tmux new-session -d -s main -t main -c ~/Code 2>/dev/null
  fi
  if ! tmux has-session -t '=main' 2>/dev/null; then
    tmux new-session -d -s main -n "$1" -c "$2" "$3"
  elif ! tmux list-windows -t '=main' -F '#W' | grep -qxF "$1"; then
    tmux new-window -d -t '=main:' -n "$1" -c "$2" "$3"
  fi
}

start claude ~/Code "$HOME/.local/bin/claude -n main"
for dir in ~/Code/*(/N); do
  if grep -q '"dev":' "$dir/package.json" 2>/dev/null; then
    start "${dir:t}" "$dir" "npm run dev"
  fi
done
EOF

# Claude Code settings, adding the ones missing and keeping what's set, and instructions
as_agent mkdir -p /Users/agent/.claude
as_agent python3 -I - <<'PY'
import json, os

path = '/Users/agent/.claude/settings.json'
settings = json.load(open(path)) if os.path.exists(path) else {}
defaults = {
    'remoteControlAtStartup': True,
    'inputNeededNotifEnabled': True,
    'agentPushNotifEnabled': True,
    'dialogExpiry': 'never',
    'modelSettings': {'claude-opus-5-5': {'effortLevel': 'xhigh'}},
    'permissions': {'defaultMode': 'auto'},
    'worktree': {'bgIsolation': 'none'},
    'preferredNotifChannel': 'terminal_bell',
}

def add_missing(target, values):
    for key, value in values.items():
        if isinstance(value, dict) and isinstance(target.get(key), dict):
            add_missing(target[key], value)
        else:
            target.setdefault(key, value)

add_missing(settings, defaults)
with open(path, 'w') as f:
    json.dump(settings, f, indent=2, ensure_ascii=False)
    f.write('\n')
PY
printf "%s\n" "$claude_md" | as_agent tee /Users/agent/.claude/CLAUDE.md > /dev/null


###############################################################################
# Machine-wide                                                                #
###############################################################################

section "Claude Code rules and the boot job"

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

section "FileVault"

# FileVault off, so the mini comes back by itself after a power cut instead of waiting at the unlock screen
if fdesetup isactive &> /dev/null; then
  ask "Turning FileVault off. Please enter your user name and password:"
  sudo fdesetup disable
fi


section "Find My"

# Find My, to locate, lock or erase a stolen mini. The Apple Account sign-in has no command, so open its settings
# and carry on once Find My is on; macos.sh turns on Location Services
find_my_on() {
  [ "$(plutil -extract FMMEnabled raw /Library/Preferences/com.apple.FindMyMac.plist 2> /dev/null)" = true ]
}
if ! find_my_on; then
  open "x-apple.systempreferences:com.apple.systempreferences.AppleIDSettings"
  ask "Please turn on Find My, in the System Settings window that just opened:"
  cat <<'EOF'
1. Sign in with your Apple Account, then turn off what iCloud syncs: the mini only needs Find My
2. iCloud → Find My Mac: turn it on, and allow it the mini's location if it asks
The script carries on once Find My Mac is on. To skip it, please press Enter.
EOF
  until find_my_on || read -r -t 5; do :; done
  if find_my_on; then
    ok "Find My is on: please check from your phone at icloud.com/find that the mini is on the map"
  else
    warn "Find My skipped: please run this script again to turn it on"
  fi
fi


section "Phone on Tailscale"

# The phone on the tailnet, or Termius can't find the mini. Device approval keeps a new device off it until approved
if ! phone_on_tailnet; then
  ask "Please put the phone on the tailnet, which Termius needs to reach the mini:"
  cat <<'EOF'
1. On the phone, install the Tailscale app from the Play Store
2. Open it, sign in with the same account as the MacBook, and turn it on
3. At login.tailscale.com → Machines, if the phone is marked Needs approval, choose Approve from its ⋯ menu
The script carries on once the phone is on the tailnet. To skip it, please press Enter.
EOF
  until phone_on_tailnet || read -r -t 5; do :; done
  if phone_on_tailnet; then
    ok "The phone is on the tailnet"
  else
    warn "Phone skipped: Termius can't reach the mini until the phone is on the tailnet"
  fi
fi


section "SSH keys"

# SSH keys for both users, then SSH locked to them
mini_ip="$(tailscale ip -4 2> /dev/null)"
ask "Please add the SSH keys of the MacBook and the phone, for both your account and agent."
cat <<EOF
Until you press Enter, SSH also takes passwords, which is how the keys get here.

${bold}MacBook${reset}: in the dotfiles folder, run ./setup-macbook.sh again, which sends its key.

${bold}Phone${reset}, with the Tailscale app on:
1. Install the Termius app from the Play Store, and open it
2. Keychain → + → New SSH Key → Generate new SSH Key: name it "phone → mini", key type ED25519, with a passphrase
3. Hosts → + → New Host: label mini, address $mini_host, username agent. Save it.
4. One more host: label mini-admin, the same address, username $(whoami). Save it.
5. Keychain → tap the key → Export to… → mini → Export. It logs in as agent, so if it asks, use username agent and
   agent's password: the one you chose when this script created the agent user, not your own.
6. Export the key again, to mini-admin. It logs in as $(whoami), so if it asks, use your own password on the mini.
Exporting also attaches the key to the host, so mini and mini-admin log in with it from then on.
Forgot agent's password? Set a new one from your account: sudo sysadminctl -resetPasswordFor agent -newPassword -
If Termius says "no address" with the phone on the tailnet, use the mini's Tailscale IP instead: $mini_ip
EOF
echo
ask "Or paste public keys here, one per line. Press Enter on an empty line when they're in: SSH then takes keys only."
while prompt key ">" && [ -n "$key" ]; do
  add_key "$key"
done

# Locked once both users have a key, unless it is already
if [ ! -e /etc/ssh/sshd_config.d/000-hardening.conf ]; then
  if [ -s ~/.ssh/authorized_keys ] && sudo test -s /Users/agent/.ssh/authorized_keys; then
    lock_ssh
    wait_for "Please test SSH, now limited to keys and the tailnet:" \
"- MacBook: ssh mini 'echo key login works', then ssh -o PubkeyAuthentication=no mini, which must fail with \"Permission denied\"
- Phone: in Termius, connect to mini and to mini-admin, which must log in with the key and not ask for a password.
  mini opens the main chat in tmux, which this script logs in to Claude next
If a test fails, run sudo rm /etc/ssh/sshd_config.d/000-hardening.conf to allow passwords again, and check the keys."
  else
    warn "SSH stays open to passwords until both users have a key: please run this script again to add them"
  fi
fi


section "Claude login for agent"

if ! as_agent zsh -lc '~/.local/bin/claude auth status' &> /dev/null; then
  ask "Please log agent in to Claude: open the link it prints, approve with your claude.ai account, and paste the code back here."
  as_agent zsh -lc 'cd ~ && ~/.local/bin/claude auth login'
  # The boot job may have started Claude before the login, restart it logged in
  as_agent zsh -lc 'tmux respawn-window -k -t main:claude' 2> /dev/null
fi


section "GitHub login for agent"

# Its own login to all your repos, so Claude can manage them with gh; it never expires. GitHub's device login, since
# the mini has no browser: the code goes in on another device. Kept in a file, since agent has no keychain
if ! as_agent zsh -lc 'gh auth status' &> /dev/null; then
  ask "Please log agent in to GitHub, with access to all your repos:"
  cat <<'EOF'
1. When it asks to authenticate Git with your GitHub credentials, press Enter for yes
2. Note the one-time code it shows, then press Enter
3. On the phone or the MacBook, open github.com/login/device, enter the code and approve GitHub CLI
EOF
  as_agent zsh -lc 'GH_BROWSER=true gh auth login --hostname github.com --git-protocol https --web \
    --scopes workflow --insecure-storage'
fi
# Git over HTTPS with that login, set again each run since the dotfiles above replace ~/.gitconfig
as_agent zsh -lc 'gh auth status &> /dev/null && gh auth setup-git'


section "Repos"

# The repos, each with its dev server running
prompt repos "Please list the repos to clone into agent's ~/Code, space-separated (name or owner/name), or press Enter to skip:"
for repo in $repos; do
  add_repo "$repo"
done
if [ -n "$repos" ]; then
  as_agent zsh -l /Users/agent/mini-up.sh
  ok "Their dev servers are running, each in the tmux window named after its repo"
fi

echo
ok "Done"
ask "Please finish with README-mac-mini.md: pin each repo's dev server port in its Vite config (step 8), bring your
Claude memory over from the MacBook (step 9), then ssh mini and answer the main chat's first questions, and check
the boot job with a power cut (step 10)."
