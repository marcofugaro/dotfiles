# ll command
alias ll='ls -alG'

# open in chrome command
alias chrome='open -a "Google Chrome"'

# autocomplete ignores case
bind 'set completion-ignore-case on'

# bash & git completition
# https://github.com/bobthecow/git-flow-completion/wiki/Install-Bash-git-completion
[ -f /usr/local/etc/bash_completion ] && . /usr/local/etc/bash_completion || {
  # if not found in /usr/local/etc, try the brew --prefix location
  [ -f "$(brew --prefix)/etc/bash_completion.d/git-completion.bash" ] && \
    . $(brew --prefix)/etc/bash_completion.d/git-completion.bash
}


# Start thefuck
# https://github.com/nvbn/thefuck
eval $(thefuck --alias)

# start sexy-bash-prompt
# https://github.com/twolfson/sexy-bash-prompt
. ~/.bash_prompt
