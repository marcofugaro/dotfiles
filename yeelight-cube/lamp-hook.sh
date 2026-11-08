#!/bin/bash
# Works out the Claude Code status for the Yeelight Cube from hook events. Across all sessions on this machine the
# most urgent state wins: input, then working, then idle, then off. cube.mjs animates whatever is in .state.
#   lamp-hook.sh <working|idle|input|off>   (the hook event's JSON arrives on stdin)
# Each session's file holds its state, the pid of its Claude process, then its transcript's path: cube.mjs uses them to
# notice what fires no hook, an interrupt or an accepted permission prompt. Each running subagent has its own file,
# <session>.<agent id>, from SubagentStart until SubagentStop, since its events carry the parent's session id and can
# outlive the parent's Stop.
# Stop the whole script on Ctrl+C, even when the interrupted command catches it
trap 'exit 130' INT
DIR=/tmp/claude-lamp
mkdir -p "$DIR"

state=$1
{
  read -r session
  read -r transcript
  read -r agent
  read -r hook_event
  read -r tool
} < <(/usr/bin/jq -r '.session_id // "default", .transcript_path // "", .agent_id // "", .hook_event_name // "",
  .tool_name // ""' 2>/dev/null)
session=${session:-default}
# A question or a plan approval is a tool call, but it waits on you until it returns
[[ $state == working && $hook_event == PreToolUse && $tool =~ ^(AskUserQuestion|ExitPlanMode)$ ]] && state=input
# A permission prompt's notification comes 6 seconds after its PermissionRequest, without the id of the subagent that
# asked, so it only counts for a prompt that fired none
[[ $hook_event == Notification ]] && grep -qsx input "$DIR/$session" "$DIR/$session".* && exit

if [[ -n $agent ]]; then
  file="$DIR/$session.$agent"
  if [[ $state == off ]]; then
    rm -f "$file"
  # Only SubagentStart creates the file, so an event arriving after SubagentStop can't bring it back
  elif [[ $hook_event == SubagentStart || -e $file ]]; then
    echo "$state" >"$file"
  fi
else
  file="$DIR/$session"
  if [[ $state == off ]]; then
    rm -f "$file" "$file".*
  elif [[ $hook_event =~ ^(Interrupt|Accept)$ ]]; then
    # Sent by cube.mjs, so the session's process and transcript stay as they were
    { read -r current && read -r pid && read -r transcript; } 2>/dev/null <"$file"
    # An accept only ends the prompt cube.mjs saw, not a state a hook wrote since
    [[ $hook_event == Accept && $current != input ]] && exit
    printf '%s\n' "$state" "$pid" "$transcript" >"$file"
    # An interrupt also ends the session's subagents, without SubagentStop
    [[ $hook_event == Interrupt ]] && rm -f "$file".*
  else
    # The Claude process running the session, the first ancestor that isn't a shell, so cube.mjs can drop the session
    # once that process exits or moves on to another session
    pid=$PPID
    for _ in 1 2 3 4; do
      read -r parent command < <(ps -o ppid=,comm= -p "$pid")
      [[ ${command##*/} =~ ^-?(sh|bash|zsh|dash)$ ]] || break
      pid=$parent
    done
    [[ ${command##*/} == *claude* || ${command##*/} =~ ^[0-9.]+$ ]] || pid=
    printf '%s\n' "$state" "$pid" "$transcript" >"$file"
  fi
fi
# A session silent for 2 hours ended without saying so
find "$DIR" -type f ! -name '.*' ! -name '*.log' -mmin +120 -delete

want=off
for s in idle working input; do
  grep -qsx "$s" "$DIR"/* && want=$s
done
# Written whole, then renamed, so cube.mjs never reads half a file
echo "$want" >"$DIR/.state.$$" && mv -f "$DIR/.state.$$" "$DIR/.state"
