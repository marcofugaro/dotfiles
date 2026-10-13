# This machine: the Mac mini

An always-on Mac mini at my main home. Nobody sits in front of it: I drive it remotely from my MacBook (VS Code
Remote-SSH, claude.ai/code) and my Android phone (the Claude app, Termius), from this home or from my second home in
another city.

## Your account

- Claude normally runs as `agent`, a standard user without admin rights. Either way, don't use `sudo`: when something
  needs an admin (Homebrew installs and upgrades, the firewall, launchd, Tailscale, SSH), give me the exact command to
  run from my admin account instead of trying a workaround.
- tmux session `main` holds the main Claude session (window `claude`) and one window per dev server, named after its
  repo. launchd starts them all at boot with `~/mini-up.sh`, and every 5 minutes restarts any that stopped, so
  restart a dev server in its own window (`tmux respawn-window -k -t main:<repo>`) rather than starting another.

## Talking to me

- I'm often on my phone. Send me a push notification when a long task finishes or needs a decision.
- Don't open apps, browser windows or anything else on the screen: nobody will see it.

## Showing me results

- Each repo in `~/Code` runs at most one dev server, on `localhost` with a port from 5173 to 5180, in a tmux window
  named after the repo. Before starting one, check whether it's already running (its tmux window, or
  `lsof -nP -iTCP:5173-5180 -sTCP:LISTEN`), and never stop another repo's server. A repo that pins its port in its
  Vite config keeps it; otherwise Vite takes the next free one.
- Link pages, and the output in `*.local/` folders, as `https://mini.<tailnet>.ts.net:<port>/<path>`, with the port
  of that repo's dev server: it works on my phone and my MacBook. On the MacBook, VS Code also forwards the ports to
  `localhost`.

## GPU and testing

- Timings from this machine aren't comparable with my MacBook Air M1 (8 GB, no fan, GPU throttles to about 750 MHz),
  which the frame budgets are tuned on. Label timings as measured on the mini, compare them only with other mini
  timings, and leave the final budget check to the Air.
- If the GPU stays near 100% with nothing running, it's wedged: stop GPU work and tell me. I can restart the mini
  remotely.
- There's no display here: any Chrome you start must be headless.

## Working in parallel

- Run long jobs in tmux or in the background: my connection can drop at any moment, and VS Code's terminals close
  with it.

## Status lamp

A Yeelight Cube on my desk shows the sessions' status, driven by the hooks in `~/.claude/settings.json` and the files
in `~/.claude/yeelight-cube/`. Leave them alone unless I ask. To change a status's colors, animation (`still`,
`breathe`, `pulse`, `spin` or `ripple`) or speed, edit `~/.claude/yeelight-cube/cube.json`; the cube picks it up
within a second. Its log is `/tmp/claude-lamp/cube.log`.
