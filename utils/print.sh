# Formatting for the setup scripts' output, sourced by each: colors on a terminal, plain text otherwise

if [ -t 1 ]; then
  bold=$'\e[1m' reverse=$'\e[7m' red=$'\e[31m' green=$'\e[32m' yellow=$'\e[33m' cyan=$'\e[36m' reset=$'\e[0m'
fi

# The script's name, first
title() {
  printf '\n%s %s %s\n' "$bold$reverse" "$1" "$reset"
}

# Each part of the script
section() {
  printf '\n%s▸ %s%s\n' "$bold$cyan" "$1" "$reset"
}

# What only you can do
ask() {
  printf '%s%s%s\n' "$bold$yellow" "$1" "$reset"
}

# A question, its answer read into the variable named first; read's options follow, like -s to hide the answer
prompt() {
  local variable="$1" question="$2"
  shift 2
  read -r "$@" -p "$bold$yellow$question$reset " "$variable"
}

# What worked
ok() {
  printf '%s✓ %s%s\n' "$green" "$1" "$reset"
}

# What was skipped, for a later run
warn() {
  printf '%s! %s%s\n' "$yellow" "$1" "$reset"
}

# What failed
fail() {
  printf '%s✗ %s%s\n' "$red" "$1" "$reset"
}
