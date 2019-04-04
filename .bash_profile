# ll command
alias ll='ls -GlAhF'

# git alias for typos
alias gti='git'

# open in chrome command
alias chrome='open -a "Google Chrome"'

# update everything
alias update='sudo softwareupdate -i -a; brew update; brew upgrade; brew cleanup; npm install npm -g; npm update -g'

# tree command preset
alias tre='tree --du -ahC -I ".git|node_modules" --dirsfirst'

# Enable aliases to be sudo’ed
alias sudo='sudo '

# intuitive map function
# for example, to list all directories that contain a certain file:
# find . -name .gitattributes | map dirname
alias map='xargs -n1'

# case-insensitive globbing (used in pathname expansion)
shopt -s nocaseglob

# autocorrect typos in path names when using `cd`
shopt -s cdspell

# enable some Bash 4 features when possible:
# * `autocd`, e.g. `**/qux` will enter `./foo/bar/baz/qux`
# * Recursive globbing, e.g. `echo **/*.txt`
shopt -s autocd 2> /dev/null
shopt -s globstar 2> /dev/null

# bash & git completition
[ -r "$(brew --prefix)/etc/profile.d/bash_completion.sh" ] && . "$(brew --prefix)/etc/profile.d/bash_completion.sh"

# start thefuck
# https://github.com/nvbn/thefuck
eval $(thefuck --alias)

# add to the path the GNU core utilities
PATH="$(brew --prefix)/opt/coreutils/libexec/gnubin:$PATH"

# init the bash prompt
source ~/.bash_prompt