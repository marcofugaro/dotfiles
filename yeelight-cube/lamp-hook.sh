#!/bin/bash
# Works out the Claude Code status for the Yeelight Cube from hook events. Across all sessions on this machine the
# most urgent state wins: input, then working, then idle, then off. cube.mjs animates whatever is in .state.
#   lamp-hook.sh <working|idle|input|off>   (the hook event's JSON arrives on stdin)
DIR=/tmp/claude-lamp
mkdir -p "$DIR"

state=$1
event=$(cat)
session=default
session_re='"session_id"[[:space:]]*:[[:space:]]*"([^"]+)"'
pre_tool_re='"hook_event_name"[[:space:]]*:[[:space:]]*"PreToolUse"'
waiting_re='"tool_name"[[:space:]]*:[[:space:]]*"(AskUserQuestion|ExitPlanMode)"'
[[ $event =~ $session_re ]] && session=${BASH_REMATCH[1]}
# A question or a plan approval is a tool call, but it waits on you until it returns
[[ $state == working && $event =~ $pre_tool_re && $event =~ $waiting_re ]] && state=input

if [[ $state == off ]]; then rm -f "$DIR/$session"; else echo "$state" >"$DIR/$session"; fi
# A session silent for 2 hours ended without saying so
find "$DIR" -type f ! -name '.*' ! -name '*.log' -mmin +120 -delete

want=off
for s in idle working input; do
  grep -qsx "$s" "$DIR"/* && want=$s
done
# Written whole, then renamed, so cube.mjs never reads half a file
echo "$want" >"$DIR/.state.$$" && mv -f "$DIR/.state.$$" "$DIR/.state"
