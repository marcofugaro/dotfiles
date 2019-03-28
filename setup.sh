#!/bin/bash

/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"

brew install cask node yarn git git-completition tldr
brew cask install google-chrome slack hyper tableplus vscode sublime-text alfred spectacle aerial kap spotify vlc adobe-photoshop-cc adobe-illustrator-cc

# Show hidden files
defaults write com.apple.finder AppleShowAllFiles YES

#  Allow Apps from Anywhere in macOS Sierra Security Gatekeeper
sudo spctl --master-disable

# remove password from sudo
sudo echo "\n# remove password for sudo\n$(whoami) ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
