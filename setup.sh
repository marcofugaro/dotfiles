#!/bin/bash

# Generate an SSH key for GitHub, skip it on Macs that shouldn't hold your personal key
read -p "Generate an SSH key for GitHub? [y/N] " ssh_key
if [[ "$ssh_key" == [yY] ]]; then
  ssh-keygen -t ed25519
  eval "$(ssh-agent -s)"
  cat >> ~/.ssh/config <<'EOF'
Host github.com
  AddKeysToAgent yes
  UseKeychain yes
  IdentityFile ~/.ssh/id_ed25519
EOF
  ssh-add --apple-use-keychain ~/.ssh/id_ed25519
  pbcopy < ~/.ssh/id_ed25519.pub
  read -p "The public key is in the clipboard: add it at https://github.com/settings/ssh/new, then press Enter "
fi

# Install Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
eval "$(/opt/homebrew/bin/brew shellenv)"


# Install GNU core utilities
brew install coreutils

# Install a newer python
brew install python

# Install commands
brew install node diff-so-fancy tree gh ghostscript bat

# Install npm global commands
npm install --global fkill-cli

# Touch ID for sudo, in tmux too
brew install pam-reattach
sudo tee /etc/pam.d/sudo_local > /dev/null <<EOF
auth       optional       $(brew --prefix)/lib/pam/pam_reattach.so
auth       sufficient     pam_tid.so
EOF

# Install Claude Code
curl -fsSL https://claude.ai/install.sh | bash

# Create the Code folder
mkdir ~/Code

# Set macOS defaults
./macos.sh

# Copy dotfiles over
cp .zshrc ~
cp .vimrc ~
cp .gitignore ~
cp .gitconfig ~

# Install zsh plugins
git clone --depth 1 https://github.com/jirutka/zsh-shift-select.git ~/.zsh/zsh-shift-select

# Copy the global Claude Code instructions over
mkdir -p ~/.claude
cp CLAUDE.md ~/.claude/CLAUDE.md

# Make zsh the default shell
chsh -s /bin/zsh

# Launch zsh
exec zsh
