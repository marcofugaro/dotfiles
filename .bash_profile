# ll command
alias ll='ls -l --human-readable --almost-all --classify --no-group --color=auto --group-directories-first --ignore=".DS_Store"'

# git alias for typos
alias gti='git'

# open in chrome command
alias chrome='open -a "Google Chrome"'

# update everything
alias update='sudo softwareupdate -i -a; brew update; brew upgrade; brew cleanup; npm update -g'

# tree command preset
alias tre='tree --du -ahC -I ".git|node_modules" --dirsfirst'

# enable aliases to be sudo’ed
alias sudo='sudo '

# intuitive map function
# for example, to list all directories that contain a certain file:
# find . -name .gitattributes | map dirname
alias map='xargs -n1'

# shorter youtube-dl command to download audio only
alias youtube-dl-mp3='youtube-dl --extract-audio --audio-format=mp3'

# always download mp4 files with youtube-dl
alias youtube-dl='youtube-dl --format "bestvideo[ext=mp4]+bestaudio[ext=m4a]/mp4"'

# shorter pdf-optimize
alias pdf-optimize='gsx-pdf-optimize'

# Redice size/bitrate of .mov file
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

  # Run ffmpeg
  ffmpeg -i "$input" -c:v libx264 -b:v "$bitrate" -c:a aac -b:a 192k "$output"
}

# get your machine's ip address
alias ip='ifconfig | grep "inet " | grep -v 127.0.0.1 | cut -d\  -f2'

# case-insensitive globbing (used in pathname expansion)
shopt -s nocaseglob

# autocorrect typos in path names when using `cd`
shopt -s cdspell

# enable some Bash 4 features when possible:
# * `autocd`, e.g. `**/qux` will enter `./foo/bar/baz/qux`
# * Recursive globbing, e.g. `echo **/*.txt`
shopt -s autocd 2> /dev/null
shopt -s globstar 2> /dev/null

# add brew to the path
eval "$(/opt/homebrew/bin/brew shellenv)"

# start thefuck
# https://github.com/nvbn/thefuck
eval $(thefuck --alias)

# bash & git completition
[ -r "$(brew --prefix)/etc/profile.d/bash_completion.sh" ] && . "$(brew --prefix)/etc/profile.d/bash_completion.sh"

# add to the path the GNU core utilities
PATH="$(brew --prefix)/opt/coreutils/libexec/gnubin:$PATH"

# run brew with the correct Apple Silicon M1 flag
ARCHFLAGS="-arch arm64"

# init the bash prompt
source ~/.bash_prompt

# set the tab title as the current path
set_tab_title() {
	local pwd_home="${PWD/#$HOME/\~}"
	echo -en "\033]0;$pwd_home\a"
}
PROMPT_COMMAND="set_tab_title"
