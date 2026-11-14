# Marks ~/Code, each git repo up to three folders deep in it, and the current folder if it's inside ~/Code, as trusted
# in ~/.claude.json, so Claude starts in any of them without the trust question.
# A trusted folder covers the folders below it, except git repos, whose trust stops at their own root.
# It holds Claude Code's own lock on the file while writing, and leaves the file alone if it can't get it.
import json, os, sys, time

config_path = os.path.expanduser('~/.claude.json')
lock = config_path + '.lock'
code = os.path.realpath(os.path.expanduser('~/Code'))
cwd = os.path.realpath(os.getcwd())

if not os.path.isdir(code) or not os.path.exists(config_path):
    sys.exit()

folders = [code]
if cwd.startswith(code + os.sep):
    folders.append(cwd)
for root, dirs, files in os.walk(code):
    if '.git' in dirs or '.git' in files:
        folders.append(root)
    depth = root[len(code):].count(os.sep)
    dirs[:] = [] if depth >= 3 else [d for d in dirs if not d.startswith('.') and d != 'node_modules']

for _ in range(30):
    try:
        os.mkdir(lock)
        break
    except FileExistsError:
        time.sleep(0.1)
else:
    sys.exit()

try:
    with open(config_path) as f:
        config = json.load(f)
    projects = config.setdefault('projects', {})
    changed = False
    for folder in dict.fromkeys(folders):
        project = projects.setdefault(folder, {})
        if project.get('hasTrustDialogAccepted') is not True:
            project['hasTrustDialogAccepted'] = True
            changed = True
    if changed:
        temp = f'{config_path}.{os.getpid()}.tmp'
        with open(os.open(temp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600), 'w') as f:
            json.dump(config, f, indent=2, ensure_ascii=False)
        os.replace(temp, config_path)
finally:
    os.rmdir(lock)
