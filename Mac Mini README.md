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
 MacBook (claude.ai/code, VS Code,      │                │   Vite dev server on localhost:5173
   Terminal) ───────────────────────────┘                │   node-webgpu tests, one at a time (GPU lock)
                                                         └─ tailscale serve → https://mini.<tailnet>.ts.net
```

- **Talking to Claude:** Remote Control. Every session on the mini appears in the Claude app and on claude.ai/code, and
  you get push notifications when a task finishes or needs a decision.
- **Full control:** SSH over Tailscale. Use Termius on the phone, and Terminal or VS Code Remote-SSH on the MacBook.
  VS Code opens the repo on the mini as if it were local; its terminal, git and the Claude Code extension all run on
  the mini.
- **Starting work:** ask the main session to do a task in a worktree, or say "use a workflow". Parallel tasks each get
  their own git worktree.
- **Testing:** agents run `npm test` and `scripts/node-page/run.js` on the mini's GPU, through `scripts/gpu-lock.js`,
  so runs never overlap.
- **Seeing results:** on the MacBook, VS Code forwards Vite's port to `localhost`, so WebGPU works in Chrome. On the
  phone, `tailscale serve` publishes Vite at an HTTPS address only your devices can reach (WebGPU needs HTTPS or
  localhost).
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
   repo, and leave your personal SSH keys, Apple ID and password manager off it.
2. **Your claude.ai account becomes a way into the mini** while Remote Control is on. claude.ai has no two-factor login
   of its own yet, so protect the Google or email account you sign in with using a security key, and turn on "Require
   trusted devices".
3. **The dev server.** Never use `tailscale funnel`, which makes a service public. Keep Vite on localhost and use
   `tailscale serve`, which only your devices can reach.
4. **A lost phone.** It holds an SSH key and a signed-in Claude app. The runbook is in step 14.

If you can't secure the claude.ai login, go SSH-only like levelsio: set `"disableRemoteControl": true` and give up the
app and push notifications.

**Already done in this repo (10 October 2026):**
- `scripts/gpu-lock.js` queues GPU runs from different sessions instead of letting them overlap.
- Vite no longer serves `.claude/settings*.json`, and is on 8.3.4, which fixes three
  security advisories.

**Still to do:**
- Lock down the dev server's `/__save-params`, `/__save-layout` and `/__save-camera` endpoints, which accept writes to
  any path from any website.
- Remove `Bash(*)` from `.claude/settings.json`. Auto mode ignores it, but switching a session to another mode brings it
  back.

### Using it from your other home

Day to day nothing changes: Remote Control, SSH, VS Code and the `tailscale serve` address all work over the internet
through Tailscale. The work is in making sure the mini comes back on its own after anything that restarts or freezes it
while you're in the other city.

| Problem while you're away | What handles it |
|---|---|
| Power cut | The mini starts again when power returns. A small UPS rides out short cuts; put the router on it too. |
| FileVault after a restart | Turn FileVault off, or keep it and unlock it remotely through an Apple TV or Raspberry Pi left on at home (step 16). |
| Claude and Vite after a restart | launchd starts the tmux session with Claude and Vite at boot (step 10). |
| The mini freezes | A smart plug you can switch from your phone: off and on again, and the mini boots. |
| macOS updates | They restart the mini, so with FileVault on, install them yourself (step 14). |
| Home internet down | Nothing to do from afar; the mini is reachable again once the connection is back. |

**FileVault with two homes:** I'd turn it off. The mini then always comes back by itself, and by design it holds
nothing you can't revoke in minutes: a GitHub token limited to this repo and your Claude login. The cost is that a thief
has an easier time getting at what's on it, so turn on Find My for your own account on the mini, which lets you lock or
erase a stolen one. If you'd rather keep FileVault, step 16 lets you unlock it from the other city; it needs an Apple TV
or Raspberry Pi that stays on at home.

---

## Part 2: Setup guide

Placeholders: `<you>` is your admin account on the mini, `<tailnet>` is your Tailscale network name (shown in the
admin console under DNS), and `<home IP>` is the mini's fixed address on your home network (step 2). The guide names
the mini `mini` and creates a second user, `agent`, which runs Claude.

### 0. Before the mini arrives (on the MacBook)

1. Commit and push your work. The mini gets the repo from GitHub; the gitignored `*.local` scratch folders and
   `.claude/worktrees` stay behind.
2. Install Tailscale on the MacBook (the standalone app from tailscale.com/download) and sign in. Turn on two-factor
   login for the account you sign in with.

### 1. First boot

1. Go through macOS setup with your own account, `<you>`. It's the admin account, used only for setup and maintenance.
2. **FileVault:** decide now (see [Using it from your other home](#using-it-from-your-other-home)). The simplest for two
   homes is to skip it when macOS asks. If you turn it on, save the recovery key in your password manager and set up
   step 16.
3. Sign your own account into your Apple ID and turn on **Find My Mac** (System Settings → your name → iCloud → Find
   My Mac), so a stolen mini can be located, locked or erased.
4. Install updates (System Settings → General → Software Update). Without FileVault, turn on automatic updates. With
   FileVault, turn off automatic installs of macOS updates and security responses: both can restart the Mac, and a
   restart leaves it locked until someone unlocks it. Update by hand instead (step 14).
5. Name the machine. Avoid anything personal: once HTTPS is on, the name ends up in public certificate logs.
   ```sh
   sudo scutil --set ComputerName mini
   sudo scutil --set HostName mini
   sudo scutil --set LocalHostName mini
   ```

### 2. Power, sharing, firewall

```sh
# Never sleep, wake on network access, restart after a power cut
sudo pmset -a sleep 0 disksleep 0 womp 1 autorestart 1

# Firewall with stealth mode; the built-in SSH server stays allowed
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setstealthmode on
```

- System Settings → General → Sharing → **Remote Login**: on. Choose "Only these users" and add `<you>`, and `agent`
  once step 3 creates it. Leave "Allow full disk access for remote users" off.
- Screen Sharing is optional, for the rare times you need the desktop.
- **Ethernet and a fixed address:** connect the mini by cable, and in your router give it a fixed address (a DHCP
  reservation); that's `<home IP>`. Unlocking FileVault from the other city (step 16) needs both: one report found the
  unlock works over Ethernet but not over Wi-Fi.
- **For running it from afar:** plug the mini into a smart plug you can switch from your phone, and set the plug to
  turn back on after a power cut. A small UPS keeps the mini and the router running through short outages.

### 3. A separate user for Claude

System Settings → Users & Groups → Add User. Choose **Standard** (not Administrator), name it `agent`, and give it a
strong password. Don't sign it into an Apple ID, a browser or a password manager.

macOS leaves home folders readable by other users, so make yours private:
```sh
sudo chmod 700 /Users/<you>
```

### 4. Tools (as `<you>`)

```sh
# Command Line Tools: git and compilers
xcode-select --install

# Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
eval "$(/opt/homebrew/bin/brew shellenv)"

# Node, tmux, Mosh, the GitHub CLI and the Tailscale daemon
brew install node tmux mosh gh tailscale
```

- `agent` can run everything Homebrew installs but can't install more, so do installs as `<you>`.
- Your MacBook runs Node 25. If a test misbehaves, install the same major version on the mini.

### 5. Tailscale

1. In the admin console (login.tailscale.com):
   - **DNS:** turn on MagicDNS and HTTPS certificates.
   - **Settings → Device management:** turn on device approval, so new devices need your OK.
   - **Access controls:** replace the default allow-all policy with this one. Your devices can reach the mini, but the
     mini can't reach them. Port 22 is SSH, 443 is `tailscale serve`, and the UDP range is Mosh.
     ```json
     {
       "tagOwners": { "tag:mini": ["autogroup:admin"] },
       "grants": [
         { "src": ["autogroup:member"], "dst": ["autogroup:self"], "ip": ["*"] },
         { "src": ["autogroup:member"], "dst": ["tag:mini"], "ip": ["tcp:22", "tcp:443", "udp:60000-61000"] }
       ]
     }
     ```
   - Never add the `funnel` attribute; Funnel makes a service public on the internet.
2. On the mini, as `<you>`:
   ```sh
   sudo tailscaled install-system-daemon
   sudo tailscale up --hostname=mini --advertise-tags=tag:mini
   ```
   Open the link it prints and approve the device. The mini is now `mini.<tailnet>.ts.net`. This daemon starts at boot,
   before anyone logs in, and tagged devices never expire off the network. It doesn't update itself, so keep it current
   (step 14).
3. On the phone, install Tailscale from the Play Store and sign in with the same account.

### 6. SSH keys

**MacBook.** Make a key just for the mini, with a passphrase:
```sh
ssh-keygen -t ed25519 -C "macbook → mini" -f ~/.ssh/id_ed25519_mini
ssh-add --apple-use-keychain ~/.ssh/id_ed25519_mini   # remembers the passphrase in the keychain
```

Add both users to `~/.ssh/config`:
```
Host mini
  HostName mini.<tailnet>.ts.net
  User agent
  IdentityFile ~/.ssh/id_ed25519_mini
  IdentitiesOnly yes
  AddKeysToAgent yes
  UseKeychain yes

Host mini-admin
  HostName mini.<tailnet>.ts.net
  User <you>
  IdentityFile ~/.ssh/id_ed25519_mini
  IdentitiesOnly yes
  AddKeysToAgent yes
  UseKeychain yes
```

Copy the key to both accounts. Each asks for that account's password, for the last time:
```sh
for host in mini mini-admin; do
  ssh "$host" 'mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys' < ~/.ssh/id_ed25519_mini.pub
done
```

**Android.** In Termius, go to Keychain → Generate key, choose ed25519, and set a passphrase. Copy the public key, then
add it to the mini from the MacBook:
```sh
ssh mini 'cat >> ~/.ssh/authorized_keys'   # paste the public key, press Enter, then Ctrl-D
```
In Termius, add a host: address `mini.<tailnet>.ts.net`, user `agent`, and that key.

**Lock SSH to keys and to your tailnet.** Do this as `<you>` on the mini (`ssh mini-admin`). Keep that session open
until the tests pass, so a mistake can't lock you out.
```sh
sudo tee /etc/ssh/sshd_config.d/000-hardening.conf >/dev/null <<'EOF'
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin no
AuthenticationMethods publickey
AllowUsers agent@100.64.0.0/10 agent@fd7a:115c:a1e0::/48 <you>@100.64.0.0/10 <you>@fd7a:115c:a1e0::/48
EOF
sudo sshd -t && echo "config OK"
```
- macOS allows password logins by default, and both of the first two lines are needed to stop them.
- The `000-` prefix makes this file win over Apple's own `100-macos.conf`.
- The new rules apply from the next connection.

Test from the MacBook:
```sh
ssh mini 'echo key login works'
ssh -o PubkeyAuthentication=no mini   # must fail with "Permission denied"
```

To keep a way in when Tailscale is down, add your home network range to `AllowUsers` (for example
`agent@192.168.1.0/24`).

### 7. GitHub access

The mini gets its own token, limited to this repo; don't copy your personal SSH key or your current gh token to it.

1. On github.com: Settings → Developer settings → Personal access tokens → **Fine-grained tokens** → Generate.
   - Repository access: only `marcofugaro/vibecoding-playground`
   - Permissions: Contents read/write, Pull requests read/write
   - Expiration: 90 days
2. On the mini, as `agent` (`ssh mini`):
   ```sh
   echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile && source ~/.zprofile
   gh auth login        # choose GitHub.com, HTTPS, then "Paste an authentication token"
   gh auth setup-git
   git config --global user.name "Marco Fugaro"
   git config --global user.email "<your email>"
   ```

### 8. The repo

As `agent`:
```sh
mkdir -p ~/Code && cd ~/Code
git clone https://github.com/marcofugaro/vibecoding-playground.git
cd vibecoding-playground
npm ci
node scripts/gpu-lock.js -- npm test
```
The last command is the real check: it runs the node-webgpu tests on the mini's GPU from an SSH session.

### 9. Claude Code

As `agent`:
```sh
curl -fsSL https://claude.ai/install.sh | bash
claude auth login    # your claude.ai account, not an API key
claude doctor
```
- If `claude` isn't found afterwards, follow the PATH line the installer prints.
- Over SSH, `claude auth login` prints a link: open it on the MacBook and paste the code back.
- SSH sessions can't unlock the keychain, so the login is saved in `~/.claude/.credentials.json`.
- Don't use an API key: Remote Control only works with a claude.ai login.

`~/.claude/settings.json` for `agent`:
```json
{
  "remoteControlAtStartup": true,
  "inputNeededNotifEnabled": true,
  "agentPushNotifEnabled": true,
  "dialogExpiry": "never",
  "modelSettings": { "claude-opus-5-5": { "effortLevel": "xhigh" } },
  "permissions": { "defaultMode": "auto" }
}
```
- `remoteControlAtStartup`: every session shows up in the Claude app without typing `/remote-control`.
- The two notification settings push to your phone when Claude needs input or has something to report.
- `dialogExpiry`: a question sent to your phone or browser otherwise expires after 5 minutes and counts as denied.
  `"never"` makes it wait for your answer.
- `modelSettings`: a top-level `effortLevel` doesn't apply to Opus 5.5.

Machine-wide rules that `agent` can't loosen (as `<you>`):
```sh
sudo mkdir -p "/Library/Application Support/ClaudeCode"
sudo tee "/Library/Application Support/ClaudeCode/managed-settings.json" >/dev/null <<'EOF'
{
  "permissions": {
    "disableBypassPermissionsMode": "disable",
    "deny": ["Read(~/.ssh/**)", "Read(~/.config/gh/**)", "Read(~/.claude/.credentials.json)"],
    "ask": ["Bash(git push *)"]
  }
}
EOF
sudo chown root:wheel "/Library/Application Support/ClaudeCode/managed-settings.json"
sudo chmod 644 "/Library/Application Support/ClaudeCode/managed-settings.json"
```
- No session can switch to bypass mode.
- The deny rules stop Claude's own file tools from reading credentials. A script could still read them, which is why
  Claude runs as a separate user with nothing valuable on it.
- The `ask` rule makes every `git push` ask you first, on your phone. Remove it if that gets tedious.

Rules for Claude on this machine are in [CLAUDE.md](CLAUDE.md), next to this guide. Replace `<tailnet>` in it with
your Tailscale network name, then copy it from the MacBook to `agent`'s `~/.claude/CLAUDE.md`:
```sh
scp ~/Desktop/mac-mini/CLAUDE.md mini:.claude/CLAUDE.md
```

Bring your Claude memory over from the MacBook. Its folder name follows the repo path, which changes because the user
is `agent`:
```sh
ssh mini 'mkdir -p ~/.claude/projects/-Users-agent-Code-vibecoding-playground'
scp -r ~/.claude/projects/-Users-marcofugaro-Code-vibecoding-playground/memory \
  mini:.claude/projects/-Users-agent-Code-vibecoding-playground/
```
From then on the two copies drift apart; treat the mini's as the main one.

### 10. Sessions that keep running: tmux

`~/.tmux.conf` for `agent`:
```
set -g mouse on
set -g history-limit 100000
```

To land in the same tmux session on every SSH login, like levelsio, add this to `~/.zshrc`. It skips VS Code's own
terminals.
```sh
if [[ -n "$SSH_CONNECTION" && -z "$TMUX" && "$TERM_PROGRAM" != "vscode" && $- == *i* ]]; then
  tmux new-session -A -s main
fi
```

Start things once; they keep running after you disconnect:
```sh
cd ~/Code/vibecoding-playground
claude -n main     # window 0: the main session, also visible in the Claude app
# Ctrl-b c opens a new window
npm run dev        # window 1: Vite on localhost:5173
# Ctrl-b d detaches; everything keeps running
```
**Bring them back after every restart.** Save this as `~/mini-up.sh` (as `agent`). It does the same as the commands
above, and does nothing if the session already exists:
```zsh
#!/bin/zsh -l
# Starts the main Claude session and the dev server in tmux, unless they're already running.
# launchd runs it at boot; after a restart you can also run it yourself: zsh -l ~/mini-up.sh
cd ~/Code/vibecoding-playground || exit 1
tmux has-session -t main 2>/dev/null && exit 0

# At boot the network can take a moment to come up, and Claude needs it
for i in {1..24}; do
  curl -sS -m 5 -o /dev/null https://api.anthropic.com && break
  sleep 5
done

tmux new-session -d -s main -n claude -c "$PWD" "$HOME/.local/bin/claude -n main"
tmux new-window -t main -n vite -c "$PWD" "npm run dev"
```

Then, as `<you>`, have launchd run it as `agent` at every boot:
```sh
sudo tee /Library/LaunchDaemons/local.mini-up.plist >/dev/null <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>local.mini-up</string>
  <key>UserName</key>
  <string>agent</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/zsh</string>
    <string>-l</string>
    <string>/Users/agent/mini-up.sh</string>
  </array>
  <key>EnvironmentVariables</key>
  <dict>
    <key>HOME</key>
    <string>/Users/agent</string>
    <key>LANG</key>
    <string>en_US.UTF-8</string>
    <key>TERM</key>
    <string>xterm-256color</string>
  </dict>
  <key>RunAtLoad</key>
  <true/>
  <key>AbandonProcessGroup</key>
  <true/>
  <key>StandardOutPath</key>
  <string>/tmp/mini-up.log</string>
  <key>StandardErrorPath</key>
  <string>/tmp/mini-up.log</string>
</dict>
</plist>
EOF
sudo chown root:wheel /Library/LaunchDaemons/local.mini-up.plist
sudo chmod 644 /Library/LaunchDaemons/local.mini-up.plist
plutil -lint /Library/LaunchDaemons/local.mini-up.plist
sudo launchctl bootstrap system /Library/LaunchDaemons/local.mini-up.plist
```

Check it once with a restart (`sudo reboot`, or `sudo fdesetup authrestart` with FileVault on):
1. About a minute later the main session should appear in the Claude app, and `ssh mini` should land in the tmux
   session.
2. Run `node scripts/gpu-lock.js -- npm test` in it. A tmux started by launchd at boot runs outside any login, and I
   couldn't confirm that macOS gives such processes the GPU. If the tests find no GPU, remove the job with
   `sudo launchctl bootout system/local.mini-up`, stop the session it started with `tmux kill-server`, and from then
   on, after each restart, run `zsh -l ~/mini-up.sh` yourself over SSH (it works from the phone too).

- **A parallel task in its own worktree:** open a new tmux window and run `claude -w <name> -n <name>`, or ask the main
  session from your phone to do the task in a worktree.
- **Without tmux:** `claude --bg` starts a background session, `claude agents` lists them, and `claude attach <id>`
  opens one.
- **tmux keys:** `Ctrl-b c` new window, `Ctrl-b n` / `Ctrl-b p` next and previous window, `Ctrl-b d` detach.

### 11. Seeing results

**On the MacBook: VS Code Remote-SSH (recommended)**
1. Install Microsoft's "Remote - SSH" extension.
2. Command palette → "Remote-SSH: Connect to Host…" → `mini` → open `~/Code/vibecoding-playground`.
3. When VS Code offers, install the Claude Code extension in that window; it runs on the mini. Its permission prompts
   and questions appear in the panel on the MacBook and, through Remote Control, in the Claude app too; answer on
   either. A chat in the panel may not survive the MacBook sleeping, so start long jobs in tmux (step 10).
4. When Vite runs on the mini, VS Code forwards its port, and the Ports panel shows the `localhost` address. Because
   it's localhost, WebGPU works in Chrome.

Without VS Code, run `ssh -N -L 5174:localhost:5173 mini` and open http://localhost:5174.

**On the phone: `tailscale serve`**
```sh
sudo tailscale serve --bg 5173    # on the mini, as <you>; the setting survives restarts
tailscale serve status            # shows what's published
```
Then open `https://mini.<tailnet>.ts.net/examples/…` in Chrome. Vite rejects hostnames it doesn't know, so add the
exact name to `vite.config.js`:
```js
server: {
  allowedHosts: ['mini.<tailnet>.ts.net'],
  // …
},
```
If hot reload doesn't connect through it, also set `server.hmr.clientPort: 443`.

### 12. Phone

- **Tailscale:** the same account as the other devices.
- **Claude:** the Code tab lists the mini's sessions. Allow notifications.
- **Termius:** the SSH host from step 6. Turn on Mosh for that host if your connection is flaky.
- **Chrome:** for the `tailscale serve` address.

For Mosh, let its server through the mini's firewall (as `<you>`):
```sh
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --add "$(readlink -f /opt/homebrew/bin/mosh-server)"
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --unblockapp "$(readlink -f /opt/homebrew/bin/mosh-server)"
```

### 13. Accounts

- **claude.ai:** it has no two-factor login of its own, so put a security key (or at least an authenticator app) on the
  Google or email account you use to sign in.
- **Trusted devices:** claude.ai → Settings → Account → **Require trusted devices** (beta). Access then needs an
  enrolled device and a sign-in less than 18 hours old. Restart running sessions after turning it on.
- **GitHub and Tailscale:** turn on two-factor login for both.

### 14. Maintenance

- **Weekly updates** (as `<you>`): `brew update && brew upgrade`. The Tailscale daemon doesn't update itself; Claude
  Code does (check with `claude doctor`).
- **Planned restart:** `sudo reboot`. With FileVault on, use `sudo fdesetup authrestart` instead, which restarts
  without stopping at the FileVault screen.
- **macOS updates with FileVault on:** first make the next restart skip the FileVault screen, then install:
  ```sh
  sudo fdesetup authrestart -delayminutes -1
  sudo softwareupdate --install --all --restart
  ```
  Apple notes the skip "may not work on all systems", so try it once while you're at the main home.
- **Power cut:** the mini starts again when power returns, and launchd brings back Claude and Vite (step 10). With
  FileVault on, it first waits at the unlock screen. macOS 26 can unlock it over SSH, but only at its home network
  address and only with your password: `ssh <you>@<home IP>`. From the main home that works directly; from the other
  city it goes through the Apple TV or Raspberry Pi (step 16).
- **Frozen mini:** switch the smart plug off and on from its app; the mini boots when power returns.
- **Lost phone:**
  1. In the Tailscale admin console, remove the phone under Machines. Access stops immediately.
  2. On the mini, delete the phone's line from `~/.ssh/authorized_keys` (for both users).
  3. On claude.ai, go to Settings → Account, log out all devices and remove the phone from trusted devices. Claude
     Code's tokens are revoked separately, under Settings → Claude Code.

### 15. Optional: a status lamp

A Yeelight Cube on your desk can animate what Claude is doing: a spinning blue gradient while it works, a pink pulse
when it needs you, a slow orange breathe when it's done. The mini drives it directly over Wi-Fi, so it keeps working
through reboots with nobody logged in, and Claude can change the colors and animations. Parts list, files and steps:
[yeelight-cube/README.md](yeelight-cube/README.md).

### 16. Only with FileVault: unlocking it from the other city

After a restart, the FileVault unlock happens before Tailscale starts, so the mini is reachable only at its home
network address. A device at home that stays on and runs Tailscale can route you onto that network from anywhere.

1. **The routing device:** an Apple TV or a Raspberry Pi, always on, on the same network as the mini. Have it advertise
   your home range, for example `192.168.1.0/24`:
   - Apple TV: install Tailscale, sign in, then Subnet Router → Advertise New Route.
   - Raspberry Pi: install Tailscale, turn on IP forwarding as Tailscale's
     [subnet router guide](https://tailscale.com/kb/1406/quick-guide-subnets) shows, then
     `sudo tailscale up --advertise-routes=192.168.1.0/24`.
2. **Approve the route** in the admin console: Machines → the device → Edit route settings.
3. **Allow it** in the access policy, next to the other grants:
   `{ "src": ["autogroup:member"], "dst": ["192.168.1.0/24"], "ip": ["tcp:22"] }`.
4. **Check the ranges differ:** if your other home's router also uses `192.168.1.x`, change one of them, or the route
   won't work from there.
5. **Test it once** from outside the home network (at the other home, or with the MacBook on your phone's hotspot):
   restart the mini with `sudo reboot`, run `ssh <you>@<home IP>` and type your password. macOS drops the connection
   while it finishes starting; a minute later `ssh mini` works and the main session is back in the Claude app.

The routing device comes back on its own after a power cut too, and the Tailscale app on the MacBook uses approved
routes automatically.

### Checklist

- [ ] Work pushed
- [ ] FileVault decided (off, or on with step 16 tested); Find My on; updates set up; machine named `mini`
- [ ] Never sleeps, restarts after a power cut, firewall and stealth mode on
- [ ] Ethernet with a fixed home address; smart plug that turns back on after a power cut; UPS if you have one
- [ ] `agent` standard user created; your home folder is `chmod 700`
- [ ] Homebrew, Node, tmux, Mosh, gh and Tailscale installed
- [ ] Tailscale: policy set, mini tagged, device approval on, no Funnel
- [ ] SSH keys from the MacBook and phone; password logins refused
- [ ] Fine-grained GitHub token; repo cloned; `node scripts/gpu-lock.js -- npm test` passes
- [ ] Claude Code logged in with claude.ai; settings, managed settings and machine notes in place; memory copied
- [ ] `mini-up.sh` brings back Claude and Vite at boot; checked after a restart, GPU tests pass there
- [ ] VS Code Remote-SSH works; `tailscale serve` plus `allowedHosts` for the phone
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
  [macOS variants](https://tailscale.com/kb/1065/macos-variants), [device approval](https://tailscale.com/kb/1099/device-approval),
  [subnet routers](https://tailscale.com/docs/features/subnet-routers), [Apple TV](https://tailscale.com/docs/install/appletv)
- Authenticated restarts: `man fdesetup` (`authrestart -delayminutes -1`) on macOS 26
- Apple, FileVault unlock over SSH: [What's new for enterprise in macOS Tahoe 26](https://support.apple.com/en-us/124963)
- levelsio: [Termius 50-50](https://x.com/levelsio/status/2074603112225235241),
  [MacinCloud build](https://x.com/levelsio/status/2074618835282649594),
  [serve-sim](https://x.com/levelsio/status/2075328941317886210),
  [tmux setup](https://x.com/levelsio/status/2057933239600263582),
  [Tailscale lockdown](https://x.com/levelsio/status/2033546675063554213)
- MacinCloud: [Dedicated](https://www.macincloud.com/pages/dedicated.html),
  [Managed](https://www.macincloud.com/pages/managed.html), [Pay-As-You-Go](https://www.macincloud.com/pages/payg.html)
- Exchange rate: [ECB reference rates](https://www.ecb.europa.eu/stats/eurofxref/eurofxref-daily.xml) (9 October 2026)
