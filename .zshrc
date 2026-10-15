# ll command
alias ll='ls -l --human-readable --almost-all --classify --no-group --color=auto --group-directories-first --ignore=".DS_Store"'

# git alias for typos
alias gti='git'

# open a file or URL in Chrome
alias chrome='open -a "Google Chrome"'

# update everything
alias update='sudo softwareupdate -i -a; brew update; brew upgrade; brew cleanup; npm update -g; git -C ~/.zsh/zsh-shift-select pull'

# tree command preset
alias tre='tree --du -ahC -I ".git|node_modules" --dirsfirst'

# enable aliases to be sudo’ed
alias sudo='sudo '

# run a command once per input line, e.g. `find . -name .gitattributes | map dirname`
alias map='xargs -n1'

# Reduce the size of a .pdf file
optimize-pdf() {
  if [ ! -f "$1" ]; then
    echo "Usage: optimize-pdf file.pdf"
    return 1
  fi

  output="${1%.*}-optimized.pdf"

  # Prevent overwrite
  if [ -f "$output" ]; then
    echo "Output already exists: $output"
    return 1
  fi

  # /ebook downsamples images to 150 dpi
  gs -sDEVICE=pdfwrite -dPDFSETTINGS=/ebook -dNOPAUSE -dQUIET -dBATCH -sOutputFile="$output" "$1"
}

# Reduce the bitrate of a .mov file
optimize-mov() {
  bitrate="8M"
  input=""

  # Parse args: -b accepted before or after the filename
  while [ $# -gt 0 ]; do
    case "$1" in
      -b) bitrate="$2"; shift 2 ;;
      -b*) bitrate="${1#-b}"; shift ;;
      -*) echo "Usage: optimize-mov [-b bitrate] file.mov"; return 1 ;;
      *) input="$1"; shift ;;
    esac
  done

  # Validate input
  if [ -z "$input" ]; then
    echo "Usage: optimize-mov [-b bitrate] file.mov"
    return 1
  fi

  if [ ! -f "$input" ]; then
    echo "File not found: $input"
    return 1
  fi

  # Build output filename
  base="${input%.*}"
  ext="${input##*.}"
  output="${base}-optimized.${ext}"

  # Prevent overwrite
  if [ -f "$output" ]; then
    echo "Output already exists: $output"
    return 1
  fi

  ffmpeg -i "$input" -c:v libx264 -b:v "$bitrate" -c:a aac -b:a 192k "$output"
}

# local IP addresses
alias ip='ifconfig | grep "inet " | grep -v 127.0.0.1 | cut -d\  -f2'

# case-insensitive globbing
setopt NO_CASE_GLOB

# cd into a directory by typing its name
setopt AUTO_CD

# add brew to the path (and its zsh completions)
eval "$(/opt/homebrew/bin/brew shellenv)"

# add to the path the GNU core utilities
PATH="$(brew --prefix)/opt/coreutils/libexec/gnubin:$PATH"

# `python` and `pip` from Homebrew
PATH="$(brew --prefix)/opt/python/libexec/bin:$PATH"

# add to the path Claude Code
PATH="$HOME/.local/bin:$PATH"

# build native extensions for arm64
ARCHFLAGS="-arch arm64"

# case-insensitive tab completion; an account that doesn't own Homebrew, like the mini's agent, trusts its
# completions instead of asking about them in every shell
autoload -Uz compinit
if [[ -O /opt/homebrew ]]; then compinit; else compinit -u; fi
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'

# emacs keybindings, which shift-select builds on
bindkey -e

# Up/Down search the history for commands starting with the typed text
autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey '^[[A' up-line-or-beginning-search
bindkey '^[[B' down-line-or-beginning-search

# select text with Shift, and whole words with Shift+Option
# https://github.com/jirutka/zsh-shift-select
[ -r ~/.zsh/zsh-shift-select/zsh-shift-select.plugin.zsh ] && source ~/.zsh/zsh-shift-select/zsh-shift-select.plugin.zsh

# set the tab title as the current path
set_tab_title() {
	print -Pn '\e]0;%~\a'
}
autoload -Uz add-zsh-hook
add-zsh-hook precmd set_tab_title

# prompt inspired by Pure https://github.com/sindresorhus/pure
# the path, then the git branch dimmed, with * for uncommitted changes
prompt_git() {
	git rev-parse --is-inside-work-tree &>/dev/null || return

	local dirty=""

	# skip the checks inside .git
	if [[ "$(git rev-parse --is-inside-git-dir 2> /dev/null)" == 'false' ]]; then
		git update-index --really-refresh -q &>/dev/null

		[[ -n "$(git status --porcelain --ignore-submodules -unormal)" ]] && dirty="*"
	fi

	# the branch, or the short SHA when detached
	local branchName="$(git symbolic-ref --quiet --short HEAD 2> /dev/null || \
		git rev-parse --short HEAD 2> /dev/null || \
		echo '(unknown)')"

	echo "${branchName}${dirty} "
}
setopt PROMPT_SUBST
# # instead of $ as root
PROMPT='%~ %{'$'\e[2m''%}$(prompt_git)%{'$'\e[22m''%}%(!.#.$) '
