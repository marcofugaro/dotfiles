-- Ctrl-V in a Tabby tab on the mini pastes this Mac's clipboard image: Claude Code there can't read this clipboard, so
-- the image goes to the mini over SSH and its path is pasted, which Claude attaches as the image. Any other Ctrl-V
-- reaches Tabby as usual.
-- Cmd-C there also copies the selection of tmux or Claude, which Tabby can't see.

-- Start at login
hs.autoLaunch(true)

local imageExtensions = { png = true, jpg = true, jpeg = true, gif = true, webp = true }
local imageFile = hs.fs.temporaryDirectory() .. "mini-clipboard.png"
local pasteKey, copyKey, upload, restore

-- The account the focused tab is on at the mini, from the title the mini sets, like agent@mini: claude
local function miniAccount()
  local window = hs.window.focusedWindow()
  local account = window and window:title():match("([%w._-]+)@mini:")
  if account == "agent" or account == os.getenv("USER") then return account end
end

-- The clipboard's image as a file and its extension: a copied image file as it is, or image data as PNG
local function clipboardImage()
  if hs.fnutils.contains(hs.pasteboard.contentTypes() or {}, "public.file-url") then
    local ok, path = hs.osascript.applescript("POSIX path of (the clipboard as «class furl»)")
    local extension = ok and path:match("%.(%w+)$")
    if extension and imageExtensions[extension:lower()] then return path, extension:lower() end
    return nil
  end
  local image = hs.pasteboard.readImage()
  if image and image:saveToFile(imageFile) then return imageFile, "png" end
end

-- Paste text with Tabby's Cmd-V, then put the clipboard back
local function pasteText(text)
  local saved = hs.pasteboard.readAllData()
  hs.pasteboard.setContents(text)
  hs.eventtap.keyStroke({ "cmd" }, "v")
  restore = hs.timer.doAfter(0.5, function() hs.pasteboard.writeAllData(saved) end)
end

-- Send the image to /tmp/<account>-clipboard on the mini, which drops the ones from over a day ago, and paste its path
local function send(file, extension, account)
  local folder = "/tmp/" .. account .. "-clipboard"
  local path = folder .. "/" .. os.date("%Y%m%d-%H%M%S") .. "." .. extension
  local command = ("umask 077 && mkdir -p %s && find %s -type f -mtime +0 -delete && cat > %s"):format(folder, folder,
    path)
  local host = account == "agent" and "mini" or "mini-admin"
  upload = hs.task.new("/bin/sh", function(code)
    upload = nil
    if code ~= 0 then
      hs.alert.show("Couldn't send the image to the mini")
    elseif hs.application.frontmostApplication():name() == "Tabby" then
      pasteText(path)
    end
  end, { "-c", '/usr/bin/ssh -o ConnectTimeout=5 -o ServerAliveInterval=5 "$1" "$2" < "$0"', file, host, command })
  upload:start()
end

pasteKey = hs.hotkey.new({ "ctrl" }, "v", function()
  if upload then return end
  local account = miniAccount()
  local file, extension
  if account then file, extension = clipboardImage() end
  if file then return send(file, extension, account) end
  pasteKey:disable()
  hs.eventtap.keyStroke({ "ctrl" }, "v")
  pasteKey:enable()
end)

-- Tabby's Cmd-C copies only Tabby's own selection, so on the mini Ctrl-Option-Shift-F12 follows it, which tmux copies
-- its selection with, or Claude's
copyKey = hs.hotkey.new({ "cmd" }, "c", function()
  copyKey:disable()
  hs.eventtap.keyStroke({ "cmd" }, "c")
  copyKey:enable()
  if miniAccount() then hs.eventtap.keyStroke({ "ctrl", "alt", "shift" }, "f12") end
end)

-- The keys are taken only while Tabby is in front. Global, so it isn't garbage collected
local function follow(app)
  if app and app:name() == "Tabby" then
    pasteKey:enable()
    copyKey:enable()
  else
    pasteKey:disable()
    copyKey:disable()
  end
end
tabbyWatcher = hs.application.watcher.new(function(_, event, app)
  if event == hs.application.watcher.activated then follow(app) end
end)
tabbyWatcher:start()
follow(hs.application.frontmostApplication())
