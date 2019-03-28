# ll command
alias ll='ls -alG'

# open in chrome command
alias chrome='open -a "Google Chrome"'

# autocomplete ignores case
bind 'set completion-ignore-case on'


# bash & git completition https://github.com/bobthecow/git-flow-completion/wiki/Install-Bash-git-completion
if [ -f $(brew --prefix)/etc/bash_completion ]; then
  . $(brew --prefix)/etc/bash_completion
fi

# start sexy-bash-prompt https://github.com/twolfson/sexy-bash-prompt
. ~/.bash_prompt

# start rbenv
eval "$(rbenv init -)"