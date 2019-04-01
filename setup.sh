#!/bin/bash

# Install brew
/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"

# Install commands
brew install cask node yarn git bash-completion tldr thefuck speedtest-cli diff-so-fancy httpie tree
npm install --global fkill-cli

# Install applications
brew tap homebrew/cask-versions
brew cask install google-chrome google-chrome-canary firefox firefox-nightly slack hyper-canary tableplus visual-studio-code sublime-text alfred spectacle aerial kap spotify vlc table-tool google-drive-file-stream

# Generate ssh key
ssh-keygen -t rsa -b 4096 -C "marco.fugaro@gmail.com"

# Copy ssh
pbcopy < ~/.ssh/id_rsa.pub

# Remove password from sudo
echo "$(whoami) ALL=(ALL) NOPASSWD: ALL" | sudo tee -a /etc/sudoers

# Ignore case in tab completition
echo "set completion-ignore-case on" | sudo tee -a /etc/inputrc

# Show hidden files
defaults write com.apple.finder AppleShowAllFiles YES

# Show file extensions
defaults write NSGlobalDomain AppleShowAllExtensions -bool true

#  Allow Apps from Anywhere in macOS Sierra Security Gatekeeper
sudo spctl --master-disable
