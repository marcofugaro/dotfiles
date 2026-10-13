#!/bin/bash

# Stop the whole script on Ctrl+C, even when the interrupted command catches it
trap 'exit 130' INT

# Say so whenever sudo stops for the admin password
export SUDO_PROMPT='Waiting for your admin password, for sudo: '

# Generate an SSH key for GitHub, skip it on Macs that shouldn't hold your personal key
read -p "Waiting for your answer: generate an SSH key for GitHub? [y/N] " ssh_key
if [[ "$ssh_key" == [yY] ]]; then
  echo "Waiting for you: press Enter to keep the key's default location, then choose a passphrase"
  ssh-keygen -t ed25519
  eval "$(ssh-agent -s)"
  cat >> ~/.ssh/config <<'EOF'
Host github.com
  AddKeysToAgent yes
  UseKeychain yes
  IdentityFile ~/.ssh/id_ed25519
EOF
  echo "Waiting for the key's passphrase, to remember it in the keychain"
  ssh-add --apple-use-keychain ~/.ssh/id_ed25519
  pbcopy < ~/.ssh/id_ed25519.pub
  read -p "Waiting for you: the public key is in the clipboard, add it at https://github.com/settings/ssh/new, then press Enter "
fi

# Install Homebrew
echo "Waiting for the Homebrew installer: it asks for your admin password, then for Enter to continue"
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
echo "Waiting for your password, to change the shell"
chsh -s /bin/zsh

# Launch zsh
exec zsh
