# Mac mini as an always-on Claude Code machine

Research and setup guide, 10 October 2026. All prices are in euros; Apple prices are from apple.com/it.

**Assumption:** the mini lives at your main home, and you use it from there and from your second home in another city,
with the MacBook and your Android phone. Everything goes through Tailscale, so neither home needs port forwarding or
router changes. What it does need is a mini that recovers from restarts on its own while you're away: see
[Using it from your other home](#using-it-from-your-other-home).

- [Part 1: Report](#part-1-report)
- [Part 2: Setup guide](#part-2-setup-guide)

---

## Part 1: Report

### Recommendation

**Buy the Mac mini M6 with 24 GB of memory and 512 GB of storage: €1,519.**

- **24 GB, not 16 GB.** Memory is soldered, so this is the choice that matters most. The 24 GB models also get faster
  memory (170 GB/s instead of 153 GB/s), which the GPU tests benefit from.
- **512 GB, not 256 GB.** The 256 GB drive is a single flash chip running at about half the speed, and the storage is
  soldered too. The upgrade costs €220.
- **If €1,299 is the limit,** pick 24 GB / 256 GB over 16 GB / 512 GB (same price), and add an external SSD later if
  space runs out.
- **Worth knowing:** Bloomberg reports an M6 14" MacBook Pro around 27 October. If you'd rather replace the Air than add
  a second machine, wait for it.

### Mac mini vs your MacBook Air

Your Mac is a MacBook Air M1 (2020): 8-core CPU, 7-core GPU, 8 GB, no fan. Under load its GPU drops from 1,278 MHz to
about 750 MHz within seconds (measured on 7 October 2026). The current Mac mini shipped on 22 September 2026 with an M6
or an M5 Pro.

| | MacBook Air M1 | Mac mini M6 | Mac mini M5 Pro |
|---|---|---|---|
| CPU, single-core | 1× | ~2× | ~1.8× |
| CPU, multi-core | 1× | ~2.5× | ~3.1× |
| GPU, peak | 1× | ~3× | ~4× |
| GPU, sustained (the Air throttles) | 1× | ~5× | ~6.5–7× |
| Memory bandwidth | 68 GB/s | 153 GB/s (16 GB), 170 GB/s (24–32 GB) | 307 GB/s |
| Memory options | 8 GB | 16, 24 or 32 GB | 24, 48 or 64 GB |
| Cooling | none | fan, inaudible in reviews | fan |

The ratios come from Geekbench 6 averages and Apple's specs. The sustained figures multiply the peak ratio by the Air's
measured throttling, so they're estimates. GPU timings from the mini won't map 1:1 onto the Air: keep final frame
budgets on the Air, or measure the same pages on both machines once to get a conversion factor.

### Memory: 16 GB or 24 GB

At the same time, the mini will run:
- macOS and its background services
- several Claude Code sessions, each with its own tool processes, plus workflow agents
- the Vite dev server
- one node-webgpu test at a time (the GPU lock), whose GPU buffers come out of the same memory
- VS Code's server, while the MacBook is connected

This MacBook shows the pressure already: on 8 GB it currently has 13.4 GB swapped out. Swap overstates the real need,
because idle processes pile up in it, but the demand is clearly well above 8 GB. On the mini it grows further: more
sessions in parallel and bigger GPU tests.

| | Verdict |
|---|---|
| **16 GB** (€1,079) | Fine for one or two sessions. MacStadium's review of these minis: 16 GB "suits a single agent more than several". Slower memory (153 GB/s). |
| **24 GB** (+€220) | Room for parallel sessions and GPU tests without swapping, and faster memory. **The minimum I'd buy.** |
| **32 GB** (+€440) | Comfortable if you expect many parallel agents or workflows. |

### Storage: 256 GB or 512 GB

What this setup takes, measured on this MacBook:

| | Size |
|---|---|
| This repo, including 7.5 GB of `*.local` scratch folders | 9.7 GB |
| Claude Code data (`~/.claude`, mostly transcripts) | 4.4 GB |
| npm cache | 2.2 GB |
| macOS and its updates, Homebrew, Node, Command Line Tools | roughly 40 GB |

That's about 55–60 GB to start, and the scratch folders and transcripts grow every week. 256 GB is enough for a
dedicated worker, but:
- **Speed:** the 256 GB models use one flash chip and run at about half the speed of the bigger drives (around
  3.2 GB/s reads). npm installs, Vite, git and swap all hit the disk.
- **No upgrade later:** the SSD is soldered on these minis (the M4's was a removable module).
- **Xcode:** if you ever build iOS apps on it, as levelsio does, Xcode alone adds tens of gigabytes.

Get 512 GB if the budget allows. Otherwise 256 GB plus an external Thunderbolt SSD for assets and backups is workable.

### Prices (apple.com/it)

| Mac mini | Price |
|---|---|
| M6, 16 GB, 256 GB | €1,079 |
| M6, 24 GB, 256 GB (custom build; check the configurator offers it) | €1,299 |
| M6, 16 GB, 512 GB | €1,299 |
| **M6, 24 GB, 512 GB** | **€1,519** |
| M6, 32 GB, 512 GB (custom build) | €1,739 |
| M5 Pro, 24 GB, 512 GB | €2,029 |
| M5 Pro, 48 GB, 512 GB (custom build) | €2,689 |

M6 upgrades: 24 GB +€220, 32 GB +€440, 512 GB +€220, 1 TB +€550. Prices went up this year with the memory shortage: the
M4 base model rose from €729 at launch to €979.

### How you'll use it

```
 Android (Claude app, Termius, Chrome) ─┐                ┌─ Mac mini, always on
                                        ├── Tailscale ───┤   tmux → Claude Code sessions (Remote Control on)
 MacBook (claude.ai/code, VS Code,      │                │   dev servers on localhost:5173–5180, one per repo
   Terminal) ───────────────────────────┘                │   node-webgpu tests, one at a time (GPU lock)
                                                         └─ tailscale serve → https://mini.<tailnet>.ts.net:<port>
```

- **Talking to Claude:** Remote Control. Every session on the mini appears in the Claude app and on claude.ai/code, and
  you get push notifications when a task finishes or needs a decision.
- **Full control:** SSH over Tailscale. Use Termius on the phone, and Terminal or VS Code Remote-SSH on the MacBook.
  VS Code opens the repo on the mini as if it were local; its terminal, git and the Claude Code extension all run on
  the mini.
- **Starting work:** ask the main session to do a task in a worktree, or say "use a workflow". Parallel tasks each get
  their own git worktree.
- **Testing:** agents run GPU tests on the mini's GPU through each repo's `scripts/gpu-lock.js`, so runs never
  overlap.
- **Seeing results:** on the MacBook, VS Code forwards the dev servers' ports to `localhost`, so WebGPU works in Chrome.
  On the phone, `tailscale serve` publishes each dev server at `https://mini.<tailnet>.ts.net:<port>`, an address only
  your devices can reach (WebGPU needs HTTPS or localhost).
- **From your other home:** the same apps and commands. Tailscale connects your devices to the mini over the internet,
  directly when it can and through Tailscale's relays when it can't, which is slower but still works. The lamp stays at
  the main home; elsewhere, the phone notifications do its job.

### Effort and ultracode from the phone

| What | How |
|---|---|
| Change effort | Type `/effort high` (or `max`, …) in the Claude app or on claude.ai/code, or use the app's effort control. It applies to that session only. |
| Ultracode for the session | `/effort ultracode`; turn it off with `/effort ultracode off` |
| Ultracode for one task | Put the word `ultracode` in the prompt. It works from the app too. |
| Start a session with it | `claude --effort ultracode` (also sets effort to xhigh) |
| Every session | `"ultracode": true` in `~/.claude/settings.json` |
| Workflow size | `"workflowSizeGuideline"`: `small`, `medium`, `large` or `unrestricted` |

If `CLAUDE_CODE_EFFORT_LEVEL` is set on the mini, sessions keep that level and changes from the phone don't apply.

### What levelsio does

Checked against his own tweets:
- **Where Claude runs:** on Hetzner VPSes, one per site. He reaches them over SSH with **Termius** from his iPhone and
  MacBook: "My work now is about 50-50 on my iPhone or MacBook Pro, both via Termius SSH to VPS!" (7 July 2026)
- **Sessions:** **tmux** keeps one session per site alive and reattaches automatically when he logs in. He has also
  used **Mosh**, and uses `/goal` to keep Claude working overnight.
- **Security:** SSH is reachable only over **Tailscale**, and web traffic comes in through a **Cloudflare Tunnel**. He
  uses key-only SSH, fail2ban, automatic updates and backups.
- **Tried and dropped:** Claude Code Remote Control (March 2026) and a Telegram bot. By June he said he only uses
  "Claude Code on VPS via Termius SSH now".
- **iOS apps:** he rents a Mac mini from **MacinCloud**, and Claude on the VPS connects to it over SSH to build with
  Xcode. He never said which plan.
- **Don't copy this part:** he runs Claude Code as root with `--dangerously-skip-permissions`. That's acceptable on a
  throwaway VPS, not on a Mac holding your keys.

MacinCloud's plans for comparison. They're priced in dollars; these are converted at the ECB rate of 9 October 2026
(€1 = $1.1206).

| Plan | SSH | Admin rights | Price |
|---|---|---|---|
| Dedicated | Yes | Full admin/sudo | M1 ~€79, M2 ~€102, M4 ~€146 per month |
| Managed | Only with a paid add-on | None | M1 ~€22, M2 ~€23, M4 ~€26 per month |
| Pay-As-You-Go | Same add-on | None | From ~€0.89 per hour or ~€3.57 per day |

The only plan that gives an agent a full shell is Dedicated. At ~€146 a month for an M4, owning a €1,519 mini pays for
itself in about ten months.

### Is it safe?

The network side is. Tailscale exposes nothing to the internet, SSH over it is fine, and Remote Control only makes
outbound HTTPS connections. The real risks, most likely first:

1. **The agent itself.** A malicious page an agent reads could trick it into sending out whatever it can read. So keep
   nothing worth stealing on the mini: run Claude as a separate non-admin user, give it a GitHub token limited to this
   repo, and leave your personal SSH keys, iCloud data and password manager off it.
2. **Your claude.ai account becomes a way into the mini** while Remote Control is on. claude.ai has no two-factor login
   of its own yet, so protect the Google or email account you sign in with using a security key, and turn on "Require
   trusted devices".
3. **The dev server.** Never use `tailscale funnel`, which makes a service public. Keep Vite on localhost and use
   `tailscale serve`, which only your devices can reach.
4. **A lost phone.** It holds an SSH key and a signed-in Claude app. The runbook is in step 14.

If you can't secure the claude.ai login, go SSH-only like levelsio: set `"disableRemoteControl": true` and give up the
app and push notifications.

**For each repo you work on from the mini:**
- Run GPU work through a lock like `scripts/gpu-lock.js`, so runs from different sessions queue instead of overlapping.
- Keep Vite up to date, and make sure it doesn't serve `.claude/settings*.json`.
- Lock down dev-server endpoints that write files, so other websites can't use them to write anywhere on disk.
- Remove `Bash(*)` from the repo's `.claude/settings.json`. Auto mode ignores it, but switching a session to another
  mode brings it back.

### Using it from your other home

Day to day nothing changes: Remote Control, SSH, VS Code and the `tailscale serve` address all work over the internet
through Tailscale. The work is in making sure the mini comes back on its own after anything that restarts or freezes it
while you're in the other city.

| Problem while you're away | What handles it |
|---|---|
| Power cut | The mini starts again when power returns. A small UPS rides out short cuts; put the router on it too. |
| FileVault after a restart | It's off, so nothing waits at an unlock screen (step 1). |
| Claude after a restart | launchd starts the tmux session with Claude and the dev servers at boot, once the internet is back (step 10). |
| The mini freezes | A smart plug you can switch from your phone: off and on again, and the mini boots. |
| macOS updates | The ones that need a restart wait for you, so they don't cut off a task (step 14). |
| Home internet down | Nothing to do from afar; the mini is reachable again once the connection is back. |

**FileVault is off,** because with it on, every power cut would stop at the unlock screen until someone types your
password. By design the mini holds nothing you can't revoke in minutes: a GitHub token limited to this repo and your
Claude login. The cost is that a thief has an easier time getting at what's on it, so Find My is on for your own
account (step 1): it shows where the mini is, locks or erases it, and its Activation Lock stops anyone else from setting
it up again.

---

## Part 2: Setup guide

Placeholders: `<you>` is your admin account on the mini, `<tailnet>` is your Tailscale network name (shown in the
admin console under DNS), and `<repo>` is one of your repos. The guide names the mini `mini` and creates a second
user, `agent`, which runs Claude.

Two scripts from the dotfiles do most of the work, from `<you>`: `setup.sh` (step 4), then `setup-mac-mini.sh`
(step 5). What they do is marked **Script** below; the rest is by hand.

### 0. Before the mini arrives (on the MacBook)

1. Commit and push your work. The mini gets your repos from GitHub; the gitignored `*.local` scratch folders and
   `.claude/worktrees` stay behind.
2. Install Tailscale on the MacBook (`setup-macbook.sh` installs the app) and sign in. Turn on two-factor login for the
   account you sign in with.

### 1. First boot

1. Go through macOS setup with your own account, `<you>`. It's the admin account, used only for setup and maintenance.
2. **FileVault:** skip it when macOS asks, so the mini always comes back by itself after a power cut (see
   [Using it from your other home](#using-it-from-your-other-home)). If it's on, `setup-mac-mini.sh` turns it off.
3. **Find My,** so a stolen mini can be located, locked or erased:
   - Location Services: `macos.sh` turns it on (step 4), or turn it on now in System Settings → Privacy & Security →
     Location Services. The mini has no GPS: it works out where it is from the Wi-Fi networks around it, so
     `setup-mac-mini.sh` keeps Wi-Fi on even with Ethernet.
   - Sign your own account into your Apple Account, then turn off what iCloud syncs: the mini only needs Find My.
   - Turn on **Find My Mac** (System Settings → your name → iCloud → Find My Mac), and allow it to use the mini's
     location if it asks.

   Find, lock or erase the mini at icloud.com/find, which works in your phone's browser, or in Find My on the MacBook.
   If you skip this now, `setup-mac-mini.sh` opens System Settings for it at the end, and carries on by itself once
   Find My is on.
4. Install updates (System Settings → General → Software Update). From then on, `macos.sh` (step 4) has the mini
   download updates and install the ones that don't need a restart; the rest wait for you (step 14).
5. **Script:** the machine is named `mini`. If you pick another name, avoid anything personal: once HTTPS is on, the
   name ends up in public certificate logs.

### 2. Power, sharing, firewall

- **Script:** the mini never sleeps, wakes on network access and restarts after a power cut. The firewall is on with
  stealth mode, and the built-in SSH server stays allowed.
- **Script:** Remote Login (System Settings → General → Sharing) is on, for "Only these users": `<you>` and `agent`.
  Leave "Allow full disk access for remote users" off.
- Screen Sharing stays off. For the rare times you need the desktop from afar, turn it on as `<you>` over SSH, and
  off again when you're done:
  ```sh
  sudo launchctl enable system/com.apple.screensharing
  sudo launchctl bootstrap system /System/Library/LaunchDaemons/com.apple.screensharing.plist
  # off again
  sudo launchctl bootout system/com.apple.screensharing
  sudo launchctl disable system/com.apple.screensharing
  ```
  The tailnet lets only SSH through to the mini, so connect through it from the MacBook:
  `ssh -N -L 5901:localhost:5900 mini`, then `open vnc://localhost:5901` and log in as `<you>`.
- **Ethernet:** connect the mini by cable if you can, it's steadier than Wi-Fi. **Script:** Wi-Fi stays on either
  way, for Find My.
- **For running it from afar:** plug the mini into a smart plug you can switch from your phone, and set the plug to
  turn back on after a power cut. A small UPS keeps the mini and the router running through short outages.


### 3. A separate user for Claude

**Script:** `setup-mac-mini.sh` creates `agent`, a standard user (not an administrator), and asks for its password;
give it a strong one. Don't sign it into an Apple ID, a browser or a password manager. The script also makes your home
folder private, since macOS leaves home folders readable by other users.

### 4. Tools (as `<you>`)

Download the dotfiles as a zip (see [README.md](README.md)), unzip them, and in that folder run:
```sh
./setup.sh
```
- It installs Homebrew, Node, gh, Claude Code and your dotfiles, and applies `macos.sh`.
- Answer **n** when it offers to generate an SSH key for GitHub: your personal key stays off the mini (step 7).
- `agent` can run everything Homebrew installs but can't install more, so do installs as `<you>`.
- Your MacBook runs Node 25. If a test misbehaves, install the same major version on the mini.

### 5. Tailscale, then the mini's setup

1. In the admin console (login.tailscale.com), before running the script:
   - **DNS:** turn on MagicDNS and HTTPS certificates.
   - **Settings → Device management:** turn on device approval, so new devices need your OK.
   - **Access controls:** replace the default allow-all policy with this one. Your devices can reach the mini, but the
     mini can't reach them. Port 22 is SSH, 5173–5180 are the dev servers, and the UDP range is Mosh.
     ```json
     {
       "tagOwners": { "tag:mini": ["autogroup:owner", "autogroup:admin"] },
       "grants": [
         { "src": ["autogroup:member"], "dst": ["autogroup:self"], "ip": ["*"] },
         { "src": ["autogroup:member"], "dst": ["tag:mini"], "ip": ["tcp:22", "tcp:5173-5180", "udp:60000-61000"] }
       ]
     }
     ```
   - Never add the `funnel` attribute; Funnel makes a service public on the internet.
2. On the mini, as `<you>`, in the dotfiles folder:
   ```sh
   ./setup-mac-mini.sh
   ```
   It does everything marked **Script** in this guide. When `tailscale up` prints a link, open it and approve the
   device; the mini is then `mini.<tailnet>.ts.net`. The Tailscale daemon starts at boot, before anyone logs in, and
   tagged devices never expire off the network. It doesn't update itself; `./setup-mac-mini.sh --update` does (step 14).
3. On the phone, install Tailscale from the Play Store and sign in with the same account.

### 6. SSH keys

**Script:** `setup-macbook.sh` makes a key just for the mini, with a passphrase, in `~/.ssh/id_ed25519_mini`, adds
`ssh mini` (as `agent`) and `ssh mini-admin` (as `<you>`) to `~/.ssh/config`, and sends the key to both users on the
mini once it's reachable. At its end, `setup-mac-mini.sh` waits for the keys while SSH still takes passwords: send the
MacBook's by running `./setup-macbook.sh` again, and the phone's with Termius's Export to host, which the script
explains. It also takes keys pasted one per line. To add keys later, run `./setup-mac-mini.sh` again.

**Lock SSH to keys and to your tailnet.** Once both users have a key, the script runs `--lock-ssh` for you. Run it
from a session you keep open until the tests pass, so a mistake can't lock you out.
- It turns off password logins, which macOS allows by default, and root logins, and accepts `agent` and `<you>` only
  from Tailscale addresses.
- Its file, `/etc/ssh/sshd_config.d/000-hardening.conf`, wins over Apple's own `100-macos.conf` thanks to the `000-`
  prefix.
- The new rules apply from the next connection.

Test from the MacBook:
```sh
ssh mini 'echo key login works'
ssh -o PubkeyAuthentication=no mini   # must fail with "Permission denied"
```

To keep a way in when Tailscale is down, add your home network range to `AllowUsers` in that file (for example
`agent@192.168.1.0/24`), and again after each `--lock-ssh`.

### 7. GitHub access

The mini gets its own token, limited to the repos it works on; don't copy your personal SSH key or your current gh
token to it.

1. On github.com: Settings → Developer settings → Personal access tokens → **Fine-grained tokens** → Generate.
   - Repository access: only the repos the mini works on
   - Permissions: Contents read/write, Pull requests read/write
   - Expiration: 90 days
2. **Script:** `setup-mac-mini.sh` asks for the token, with these same steps, and logs `agent` in to `gh` with it.
   `agent`'s git name and email come from your `.gitconfig`.

### 8. The repos

**Script:** `setup-mac-mini.sh` asks which repos to clone, then for each one clones it as `agent` into `~/Code`, runs
`npm ci`, and starts its dev server in a tmux window named after the repo (step 10). To add repos later, run
`./setup-mac-mini.sh` again.
- If the repo has GPU tests, run them once through its lock, for example `node scripts/gpu-lock.js -- npm test`. It's
  the real check that SSH sessions get the mini's GPU.
- **Ports:** each repo's dev server gets its own port from 5173 to 5180. Pin it in the repo's Vite config, so its
  address never changes:
  ```js
  server: { port: 5174, strictPort: true },
  ```
  Without that, Vite takes the next free port, and the order you start them in decides which repo gets which.

### 9. Claude Code

**Script:** `setup-mac-mini.sh` installs Claude Code for `agent`, in `~/.local/bin`, where it updates itself. It also
writes:
- `agent`'s `~/.claude/settings.json`, if there's none yet:
  - `remoteControlAtStartup`: every session shows up in the Claude app without typing `/remote-control`.
  - `inputNeededNotifEnabled` and `agentPushNotifEnabled` push to your phone when Claude needs input or has something
    to report.
  - `dialogExpiry: "never"`: a question sent to your phone or browser otherwise expires after 5 minutes and counts as
    denied.
  - `modelSettings` sets the effort to xhigh: a top-level `effortLevel` doesn't apply to Opus 5.5.
  - `permissions.defaultMode: "auto"`.
- Machine-wide rules that `agent` can't loosen, in `/Library/Application Support/ClaudeCode/managed-settings.json`:
  - No session can switch to bypass mode.
  - Claude's own file tools can't read credentials. A script could still read them, which is why Claude runs as a
    separate user with nothing valuable on it.
  - Every `git push` asks you first, on your phone. Remove that rule if it gets tedious.
- The rules for Claude on this machine, [CLAUDE.md](CLAUDE.md) followed by [CLAUDE-mac-mini.md](CLAUDE-mac-mini.md), in
  `~/.claude/CLAUDE.md` for both users, with your tailnet name filled in.

**Script:** `setup-mac-mini.sh` runs `claude auth login` as `agent`, unless it's logged in already: open the link it
prints, approve with your claude.ai account (not an API key), and paste the code back. Check it afterwards with
`claude doctor` as `agent`.
- SSH sessions can't unlock the keychain, so the login is saved in `~/.claude/.credentials.json`.
- Don't use an API key: Remote Control only works with a claude.ai login.

Bring your Claude memory over from the MacBook, for each repo. Its folder name follows the repo path, which changes
because the user is `agent`:
```sh
ssh mini 'mkdir -p ~/.claude/projects/-Users-agent-Code-<repo>'
scp -r ~/.claude/projects/-Users-marcofugaro-Code-<repo>/memory mini:.claude/projects/-Users-agent-Code-<repo>/
```
From then on the two copies drift apart; treat the mini's as the main one.

### 10. Sessions that keep running: tmux

**Script:** for `agent`, `setup-mac-mini.sh` sets up:
- `~/.tmux.conf`, with the mouse on and a long scrollback.
- A few lines in `~/.zshrc` that land every SSH login in the tmux session `main`, like levelsio. They skip VS Code's
  own terminals.
- `~/mini-up.sh`, which waits for the internet, then starts the main Claude session in tmux window `claude`, in
  `~/Code`, and each repo's dev server in a window named after the repo, skipping what's already running. A launchd
  job runs it as `agent` at every boot, before anyone logs in, and every 5 minutes after, so Claude or a dev server
  that stops comes back. To stop a dev server for good, move its repo out of `~/Code`. You can also run it yourself:
  `zsh -l ~/mini-up.sh`.

The script starts the dev servers of the repos it clones. To start one yourself, in its own window named after the
repo, which keeps running after you disconnect:
```sh
tmux new-window -t main -n <repo> -c ~/Code/<repo> "npm run dev"
```

Check the boot job once with a power cut: switch the smart plug off and on, or run `sudo reboot`.
1. About a minute later the main session should appear in the Claude app, and `ssh mini` should land in the tmux
   session.
2. Run a repo's GPU tests in it. A tmux started by launchd at boot runs outside any login, and I couldn't confirm that
   macOS gives such processes the GPU. If the tests find no GPU, remove the job with
   `sudo launchctl bootout system/local.mini-up`, stop the session it started with `tmux kill-server`, and from then
   on, after each restart, run `zsh -l ~/mini-up.sh` yourself over SSH (it works from the phone too).

- **A parallel task in its own worktree:** open a new tmux window and run `claude -w <name> -n <name>`, or ask the main
  session from your phone to do the task in a worktree.
- **Without tmux:** `claude --bg` starts a background session, `claude agents` lists them, and `claude attach <id>`
  opens one.
- **tmux keys:** `Ctrl-b c` new window, `Ctrl-b n` / `Ctrl-b p` next and previous window, `Ctrl-b d` detach.

### 11. Seeing results

**On the MacBook: VS Code Remote-SSH (recommended)**
1. Install Microsoft's "Remote - SSH" extension (`setup-macbook.sh` does).
2. Command palette → "Remote-SSH: Connect to Host…" → `mini` → open `~/Code/<repo>`.
3. When VS Code offers, install the Claude Code extension in that window; it runs on the mini. Its permission prompts
   and questions appear in the panel on the MacBook and, through Remote Control, in the Claude app too; answer on
   either. A chat in the panel may not survive the MacBook sleeping, so start long jobs in tmux (step 10).
4. When a dev server runs on the mini, VS Code forwards its port, and the Ports panel shows the `localhost` address.
   Because it's localhost, WebGPU works in Chrome.

Without VS Code, run `ssh -N -L <port>:localhost:<port> mini` and open `http://localhost:<port>`.

**On the phone: `tailscale serve`**

**Script:** `setup-mac-mini.sh` publishes ports 5173–5180 with `tailscale serve`, each at the same port on the mini's
tailnet address, where only your devices can reach it. Open a repo's dev server at
`https://mini.<tailnet>.ts.net:<port>/` in Chrome; `tailscale serve status` shows what's published.
- Vite rejects hostnames it doesn't know. The script allows the tailnet name for every repo through
  `__VITE_ADDITIONAL_SERVER_ALLOWED_HOSTS` in `agent`'s `~/.zprofile`, so no repo needs `allowedHosts`.
- Hot reload should connect through it, because the page's port is the dev server's port. If it doesn't, set
  `server.hmr.clientPort` to that port in the repo's Vite config.

### 12. Phone

- **Tailscale:** the same account as the other devices.
- **Claude:** the Code tab lists the mini's sessions. Allow notifications.
- **Termius:** the SSH host from step 6. Turn on Mosh for that host if your connection is flaky.
- **Chrome:** for the dev servers' addresses.

**Script:** Mosh's server is let through the mini's firewall.

### 13. Accounts

- **claude.ai:** it has no two-factor login of its own, so put a security key (or at least an authenticator app) on the
  Google or email account you use to sign in.
- **Trusted devices:** claude.ai → Settings → Account → **Require trusted devices** (beta). Access then needs an
  enrolled device and a sign-in less than 18 hours old. Restart running sessions after turning it on.
- **GitHub and Tailscale:** turn on two-factor login for both.

### 14. Maintenance

- **Weekly updates:** as `<you>`, in the dotfiles folder and inside tmux, run `./setup-mac-mini.sh --update`. It runs
  `brew update && brew upgrade`, then lets the new Mosh (and the lamp's Node) through the firewall again and reinstalls
  the Tailscale daemon, which Homebrew doesn't update. Restarting Tailscale can drop SSH sessions over it for a moment.
  Claude Code updates itself (check with `claude doctor`).
- **macOS updates:** the mini downloads them by itself and installs the ones that don't need a restart. Install the
  rest when it suits you: `sudo softwareupdate --install --all --restart`.
- **Planned restart:** `sudo reboot`.
- **Power cut:** the mini starts again when power returns, and launchd brings back the main Claude session and the dev
  servers once the internet is back (step 10).
- **Frozen mini:** switch the smart plug off and on from its app; the mini boots when power returns.
- **Lost phone:**
  1. In the Tailscale admin console, remove the phone under Machines. Access stops immediately.
  2. On the mini, delete the phone's line from `~/.ssh/authorized_keys` (for both users).
  3. On claude.ai, go to Settings → Account, log out all devices and remove the phone from trusted devices. Claude
     Code's tokens are revoked separately, under Settings → Claude Code.

### 15. Optional: a status lamp

A Yeelight Cube on your desk can animate what Claude is doing: a spinning blue gradient while it works, a pink pulse
when it needs you, a slow orange breathe when it's done. The mini drives it directly over Wi-Fi, so it keeps working
through reboots with nobody logged in, and Claude can change the colors and animations. Parts list and how it works:
[yeelight-cube/README.md](yeelight-cube/README.md). Once the cube is on your Wi-Fi with a fixed address, run
`./setup-mac-mini-status-lamp.sh` as `<you>` in the dotfiles folder to install it.

### Checklist

- [ ] Work pushed
- [ ] FileVault off; Location Services and Find My on, with the mini on the map at icloud.com/find; updates installed
- [ ] Ethernet if you can, Wi-Fi left on; smart plug that turns back on after a power cut; UPS if you have one
- [ ] Tailscale console: policy set, device approval on, MagicDNS and HTTPS certificates on, no Funnel
- [ ] `setup.sh` and `setup-mac-mini.sh` run; the mini approved in Tailscale; Remote Login on
- [ ] SSH keys from the MacBook and the phone; `--lock-ssh` run and password logins refused
- [ ] Fine-grained GitHub token; repos cloned, each with its own port; GPU tests pass over SSH
- [ ] Claude Code logged in as `agent` with claude.ai; memory copied
- [ ] The main Claude session comes back after a restart, and GPU tests pass there
- [ ] VS Code Remote-SSH works; the dev servers open at `https://mini.<tailnet>.ts.net:<port>` on the phone
- [ ] Tried everything from outside the home network: SSH, VS Code, the Claude app
- [ ] Security key on the claude.ai sign-in account; trusted devices on

---

### Sources

- Apple: [Mac mini specs](https://www.apple.com/mac-mini/specs/),
  [apple.com/it store](https://www.apple.com/it/shop/buy-mac/mac-mini),
  [M6 / M5 Pro announcement](https://www.apple.com/newsroom/2026/08/apple-unveils-a-more-powerful-mac-mini-featuring-the-all-new-m6-and-m5-pro/)
- Upgrade prices: [Macitynet](https://www.macitynet.it/mac-mini-m6-o-m5-pro-tutti-i-prezzi-di-ram-e-ssd-e-le-configurazioni-piu-convenienti/)
- Benchmarks and reviews: [EveryMac Mac mini](https://everymac.com/mac-benchmarks/all-apple-silicon-mac-mini-benchmarks.html),
  [EveryMac MacBook Air](https://everymac.com/mac-benchmarks/all-apple-silicon-macbook-air-13-inch-benchmarks.html),
  [MacRumors M6 GPU](https://www.macrumors.com/2026/09/18/m5-ultra-and-m6-chip-gpu-benchmarks/),
  [MacStadium](https://macstadium.com/blog/mac-mini-with-m6-and-m5-pro-benchmarks-and-use-cases),
  [Tom's Guide](https://www.tomsguide.com/computing/apple-desktops/mac-mini-m6-review)
- Claude Code docs: [Remote Control](https://code.claude.com/docs/en/remote-control),
  [model configuration and effort](https://code.claude.com/docs/en/model-config),
  [workflows](https://code.claude.com/docs/en/workflows), [setup](https://code.claude.com/docs/en/setup),
  [permission modes](https://code.claude.com/docs/en/permission-modes),
  [managed settings](https://code.claude.com/docs/en/managed-settings)
- Tailscale: [Serve](https://tailscale.com/kb/1312/serve), [Funnel](https://tailscale.com/kb/1223/funnel),
  [macOS variants](https://tailscale.com/kb/1065/macos-variants), [device approval](https://tailscale.com/kb/1099/device-approval)
- levelsio: [Termius 50-50](https://x.com/levelsio/status/2074603112225235241),
  [MacinCloud build](https://x.com/levelsio/status/2074618835282649594),
  [serve-sim](https://x.com/levelsio/status/2075328941317886210),
  [tmux setup](https://x.com/levelsio/status/2057933239600263582),
  [Tailscale lockdown](https://x.com/levelsio/status/2033546675063554213)
- MacinCloud: [Dedicated](https://www.macincloud.com/pages/dedicated.html),
  [Managed](https://www.macincloud.com/pages/managed.html), [Pay-As-You-Go](https://www.macincloud.com/pages/payg.html)
- Exchange rate: [ECB reference rates](https://www.ecb.europa.eu/stats/eurofxref/eurofxref-daily.xml) (9 October 2026)
