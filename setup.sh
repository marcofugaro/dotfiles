#!/bin/bash


# Generate ssh key
ssh-keygen -t rsa -b 4096 -C "marco.fugaro@gmail.com"

# Copy ssh and wait for user to insert it in github
pbcopy < ~/.ssh/id_rsa.pub
echo "Now login to https://github.com/settings/keys and add the key that has already been copied to your clipboard."
read -p "Press any key to continue. Ctrl-C to abort."

# Remove password from sudo
echo "Removing password from sudo..."
echo "$(whoami) ALL=(ALL) NOPASSWD: ALL" | sudo tee -a /etc/sudoers

# Install xcode command line tools
xcode-select --install

# Install rosetta binaries
sudo softwareupdate --install-rosetta

# Install brew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
eval "$(/opt/homebrew/bin/brew shellenv)"


# Install GNU core utilities (those that come with macOS are outdated)
brew install coreutils

# Install more recent versions of some macOS tools.
brew install vim grep openssh screen python git bash bash-completion2

# Install commands
brew install cask node tldr thefuck diff-so-fancy tree hub youtube-dl webtorrent-cli

# Install quick-look-plugins
brew install --cask qlcolorcode qlstephen qlmarkdown quicklook-json qlimagesize webpquicklook qlvideo gltfquicklook

# Install npm global commands
npm install --global fkill-cli speed-test glob-cmd trash-cli yo gsx-pdf-optimize

# Install applications
brew tap homebrew/cask-versions
brew install --cask google-chrome google-chrome-canary firefox-nightly slack discord hyper visual-studio-code sublime-text alfred spotify vlc table-tool android-file-transfer mysides blender

# Install vscode and hyper settings extensions
code --install-extension shan.code-settings-sync

# Create Code folder
mkdir ~/Code

# Set MacOS defaults
./macos.sh

# Copy dotfiles over
cp .bash_profile ~
cp .bash_prompt ~
cp .inputrc ~
cp .gitignore ~
cp .gitconfig ~
cp .hyper.js ~
cp .hyper-postprocessing.js ~

# Install fonts
cp ProFontWindows.ttf ~/Library/Fonts

# Change default shell to bash
sudo sh -c "echo $(which bash) >> /etc/shells"
chsh -s $(which bash)

# Launch bash
exec bash
