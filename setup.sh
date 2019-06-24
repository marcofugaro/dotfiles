#!/bin/bash

# Generate ssh key
ssh-keygen -t rsa -b 4096 -C "marco.fugaro@gmail.com"

# Copy ssh and wait for user to insert it in github
pbcopy < ~/.ssh/id_rsa.pub
echo "Now login to https://github.com/settings/keys and add the key that has already been copied to your clipboard."
read -p "Press any key to continue. Ctrl-C to abort."

# Remove password from sudo
echo "$(whoami) ALL=(ALL) NOPASSWD: ALL" | sudo tee -a /etc/sudoers

# Install xcode
xcode-select --install

# Install brew
/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"

# Install GNU core utilities (those that come with macOS are outdated)
brew install coreutils

# Install more recent versions of some macOS tools.
brew install vim grep openssh screen python git bash bash-completion2

# Install commands
brew install cask node yarn yarn-completion tldr thefuck diff-so-fancy httpie tree hub youtube-dl ffmpeg

# Install quuick-look-plugins
brew cask install qlcolorcode qlstephen qlmarkdown quicklook-json qlimagesize webpquicklook qlvideo

# Install npm global commands
npm install --global fkill-cli speed-test glob-cmd trash-cli yo gsx-pdf-optimize

# Install applications
brew tap homebrew/cask-versions
brew cask install google-chrome google-chrome-canary firefox firefox-nightly slack hyper-canary tableplus visual-studio-code sublime-text alfred spectacle aerial kap spotify vlc table-tool google-drive-file-stream webtorrent-cli android-file-transfer

# Set MacOS defaults
./macos.sh

# Set up Spectacle.app keyboard shortcuts
cp spectacle.json ~/Library/Application\ Support/Spectacle/Shortcuts.json

# Copy dotfiles over
cp .bash_profile ~
cp .bash_prompt ~
cp .inputrc ~
cp .gitignore ~
cp .gitconfig ~
cp .hyper-postprocessing.js ~

# Install fonts
cp ProFontWindows.ttf ~/Library/Fonts