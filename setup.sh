#!/bin/bash

# Install brew
/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"

# Install commands
brew install cask node yarn git tldr

# Install applications
brew tap homebrew/cask-versions
brew cask install google-chrome google-chrome-canary firefox firefox-nightly slack hyper tableplus visual-studio-code sublime-text alfred spectacle aerial kap spotify vlc table-tool

# Show hidden files
defaults write com.apple.finder AppleShowAllFiles YES

#  Allow Apps from Anywhere in macOS Sierra Security Gatekeeper
sudo spctl --master-disable

# Remove password from sudo
sudo su
echo "\n# remove password for sudo\n$(whoami) ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
exit