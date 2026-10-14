#!/bin/bash

# Stop the whole script on Ctrl+C, even when the interrupted command catches it
trap 'exit 130' INT

# Say so whenever sudo stops for the admin password
export SUDO_PROMPT='Waiting for your admin password, for sudo: '

# MacBook setup: run after setup.sh. Safe to run again: it skips what's done, and run it again when
# setup-mac-mini.sh asks for SSH keys, to send the MacBook's.

# Install applications
brew install --cask google-chrome visual-studio-code android-file-transfer blender tabby tailscale-app

# Set the Dock apps, after Finder
dock_item() {
  printf '<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>%s</string><key>_CFURLStringType</key><integer>0</integer></dict></dict></dict>' "$1"
}
defaults write com.apple.dock persistent-apps -array \
  "$(dock_item /Applications/Google\ Chrome.app)" \
  "$(dock_item /Applications/Visual\ Studio\ Code.app)" \
  "$(dock_item /Applications/Tabby.app)"
killall Dock

# Open VS Code projects on the Mac mini over SSH
code --install-extension ms-vscode-remote.remote-ssh

# A key just for the mini, and `ssh mini` (agent) and `ssh mini-admin` (your account, same name as here) over MagicDNS
if [ ! -e ~/.ssh/id_ed25519_mini ]; then
  echo "Waiting for a passphrase for the mini's SSH key"
  ssh-keygen -t ed25519 -C "macbook → mini" -f ~/.ssh/id_ed25519_mini
  echo "Waiting for that passphrase again, to remember it in the keychain"
  ssh-add --apple-use-keychain ~/.ssh/id_ed25519_mini
fi
grep -q '^Host mini$' ~/.ssh/config 2> /dev/null || cat >> ~/.ssh/config <<EOF

Host mini
  User agent

Host mini-admin
  User $(whoami)

Host mini mini-admin
  HostName mini
  IdentityFile ~/.ssh/id_ed25519_mini
  IdentitiesOnly yes
  AddKeysToAgent yes
  UseKeychain yes
EOF

# Send the key to both users on the mini, while it still takes passwords; ssh-copy-id skips it where it's there
if nc -z -G 5 mini 22 &> /dev/null; then
  echo "Sending the mini's SSH key: ssh-copy-id asks for your password on the mini, then agent's"
  ssh-copy-id -i ~/.ssh/id_ed25519_mini.pub mini-admin && ssh-copy-id -i ~/.ssh/id_ed25519_mini.pub mini
else
  echo "The mini isn't reachable yet: once setup-mac-mini.sh asks for SSH keys, run ./setup-macbook.sh again"
fi

# The global Claude Code instructions; on the mini, setup-mac-mini.sh writes them with its own rules added
mkdir -p ~/.claude
cp CLAUDE.md ~/.claude/CLAUDE.md

# Copy the Tabby config over
mkdir -p ~/Library/Application\ Support/tabby
cp tabby-config.yaml ~/Library/Application\ Support/tabby/config.yaml

# Install fonts
cp ProFontWindows.ttf ~/Library/Fonts

# Sleep the display and the Mac after 90 minutes on power
sudo pmset -c displaysleep 90
sudo pmset -c sleep 90
