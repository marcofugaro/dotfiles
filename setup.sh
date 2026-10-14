#!/bin/bash

# Stop the whole script on Ctrl+C, even when the interrupted command catches it
trap 'exit 130' INT

# Say so whenever sudo stops for the admin password
export SUDO_PROMPT='Please enter your admin password, for sudo: '

# Setup for every Mac, before its own setup script. Safe to run again: it skips what's done.

# Generate an SSH key for GitHub, unless there's one; skip it on Macs that shouldn't hold your personal key
[ -e ~/.ssh/id_ed25519 ] || read -p "Please answer: generate an SSH key for GitHub? [y/N] " ssh_key
if [[ "$ssh_key" == [yY] ]]; then
  echo "Please press Enter to keep the key's default location, then choose a passphrase"
  ssh-keygen -t ed25519
  eval "$(ssh-agent -s)"
  cat >> ~/.ssh/config <<'EOF'
Host github.com
  AddKeysToAgent yes
  UseKeychain yes
  IdentityFile ~/.ssh/id_ed25519
EOF
  echo "Please enter the key's passphrase again, to remember it in the keychain"
  ssh-add --apple-use-keychain ~/.ssh/id_ed25519
  pbcopy < ~/.ssh/id_ed25519.pub
  read -p "Please add the public key, now in the clipboard, at https://github.com/settings/ssh/new, then press Enter "
fi

# Install Homebrew
if [ ! -x /opt/homebrew/bin/brew ]; then
  echo "Please enter your admin password when the Homebrew installer asks for it, then press Enter to continue"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
eval "$(/opt/homebrew/bin/brew shellenv)"

# Install Homebrew packages, unless installed already, so a rerun doesn't upgrade them
brew_install() {
  for package in "$@"; do
    brew list "$package" &> /dev/null || brew install "$package"
  done
}


# Install GNU core utilities
brew_install coreutils

# Install a newer python
brew_install python

# Install commands
brew_install node diff-so-fancy tree gh ghostscript bat

# Install npm global commands
command -v fkill > /dev/null || npm install --global fkill-cli

# Touch ID for sudo, in tmux too
brew_install pam-reattach
sudo tee /etc/pam.d/sudo_local > /dev/null <<EOF
auth       optional       $(brew --prefix)/lib/pam/pam_reattach.so
auth       sufficient     pam_tid.so
EOF

# Install Claude Code, which then updates itself
[ -x ~/.local/bin/claude ] || curl -fsSL https://claude.ai/install.sh | bash

# Create the Code folder
mkdir -p ~/Code

# Set macOS defaults
./macos.sh

# Copy dotfiles over
cp .zshrc ~
cp .vimrc ~
cp .gitignore ~
cp .gitconfig ~

# Install zsh plugins
[ -d ~/.zsh/zsh-shift-select ] || git clone --depth 1 https://github.com/jirutka/zsh-shift-select.git ~/.zsh/zsh-shift-select

mkdir -p ~/.claude

# Claude Code settings, merged into what's there: Opus at xhigh effort, the colorblind-friendly dark theme, and
# background sessions that edit the checkout in place, without a worktree
python3 -I - <<'PY'
import json, os

path = os.path.expanduser('~/.claude/settings.json')
settings = json.load(open(path)) if os.path.exists(path) else {}
settings['model'] = 'opus'
settings.setdefault('modelSettings', {}).setdefault('claude-opus-5-5', {})['effortLevel'] = 'xhigh'
settings['theme'] = 'dark-daltonized'
settings.setdefault('worktree', {})['bgIsolation'] = 'none'
with open(path, 'w') as f:
    json.dump(settings, f, indent=2)
    f.write('\n')
PY

# Make zsh the default shell
if [[ "$(dscl . -read "/Users/$(whoami)" UserShell)" != *" /bin/zsh" ]]; then
  echo "Please enter your password, to change the shell"
  chsh -s /bin/zsh
fi

# Launch zsh
exec zsh
