#!/bin/bash

# MacBook setup: run after setup.sh.

# Install applications
brew install --cask google-chrome visual-studio-code android-file-transfer blender tabby tailscale-app

# Open VS Code projects on the Mac mini over SSH
code --install-extension ms-vscode-remote.remote-ssh

# Copy the Tabby config over
mkdir -p ~/Library/Application\ Support/tabby
cp tabby-config.yaml ~/Library/Application\ Support/tabby/config.yaml

# Install fonts
cp ProFontWindows.ttf ~/Library/Fonts

# Sleep the display and the Mac after 90 minutes on power
sudo pmset -c displaysleep 90
sudo pmset -c sleep 90
