#!/bin/bash

# Disable the “Are you sure you want to open this application?” dialog
defaults write com.apple.LaunchServices LSQuarantine -bool false

# Expand save panel by default
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true

# Automatically quit printer app once the print jobs complete
defaults write com.apple.print.PrintingPrefs "Quit When Finished" -bool true

# Disable long-press keys to show accent menu
defaults write -g ApplePressAndHoldEnabled -bool false

# Disable Notification Center and remove the menu bar icon
launchctl unload -w /System/Library/LaunchAgents/com.apple.notificationcenterui.plist 2> /dev/null

# Enable Safari’s debug menu
defaults write com.apple.Safari IncludeInternalDebugMenu -bool true

# Enable the Develop menu and the Web Inspector in Safari
defaults write com.apple.Safari IncludeDevelopMenu -bool true
defaults write com.apple.Safari WebKitDeveloperExtrasEnabledPreferenceKey -bool true
defaults write com.apple.Safari com.apple.Safari.ContentPageGroupIdentifier.WebKit2DeveloperExtrasEnabled -bool true

# Show all processes in Activity Monitor
defaults write com.apple.ActivityMonitor ShowCategory -int 0

# Sort Activity Monitor results by CPU usage
defaults write com.apple.ActivityMonitor SortColumn -string "CPUUsage"
defaults write com.apple.ActivityMonitor SortDirection -int 0

# Set the Google's dns servers
networksetup -setdnsservers Wi-Fi 8.8.8.8
networksetup -setdnsservers Wi-Fi 8.8.4.4

# Disable two-finger back/forward navigation on Chrome
defaults write com.google.Chrome AppleEnableSwipeNavigateWithScrolls -bool false


###############################################################################
# Preferences                                                                 #
###############################################################################

# Disable automatic app store updates
sudo defaults write /Library/Preferences/com.apple.commerce AutoUpdate -bool false

# Disable macOS automatic updates
sudo defaults write /Library/Preferences/com.apple.commerce AutoUpdateRestartRequired -bool false

# Disable automatic Software Update update checks
sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticCheckEnabled -bool false

# Disable automatic software update download
sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticDownload -bool false

# Disable Notification Centre
defaults write com.apple.AppleMultitouchTrackpad.plist TrackpadTwoFingerFromRightEdgeSwipeGesture -bool false

# Disable Force click to look up
defaults write "Apple Global Domain" com.apple.trackpad.forceClick -bool false

# Disable automatically rearrange Spaces based on recent use
defaults write com.apple.dock mru-spaces -bool false

# Disable screensaver
defaults -currentHost write com.apple.screensaver idleTime 0

# Set display sleep minutes when using power adapter
sudo pmset -c displaysleep 90
sudo pmset -c sleep 90

# Set a blazingly fast keyboard repeat rate
defaults write NSGlobalDomain KeyRepeat -int 1
defaults write NSGlobalDomain InitialKeyRepeat -int 20

# Restart the preferences
killall cfprefsd

# Add crontab to kill the new quicklook
echo "0 9 * * * pkill -9 -f QuickLookUIService" | crontab -


###############################################################################
# Dock                                                                        #
###############################################################################

# Customize the app icons from the Dock
dock_item() {
    printf '<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>%s</string><key>_CFURLStringType</key><integer>0</integer></dict></dict></dict>', "$1"
}

defaults write com.apple.dock persistent-apps -array \
    "$(dock_item /Applications/Google\ Chrome.app)" \
    "$(dock_item /Applications/Visual\ Studio\ Code.app)" \
    "$(dock_item /Applications/Hyper.app)" \
    "$(dock_item /Applications/Discord.app)"

# Hide recent section
defaults write com.apple.dock "show-recents" -bool "false"

# Restart the dock
killall Dock


###############################################################################
# Finder                                                                      #
###############################################################################

# Show hidden files
defaults write com.apple.finder AppleShowAllFiles -bool true

# Show file extensions
defaults write NSGlobalDomain AppleShowAllExtensions -bool true

# Set Home as the default location for new Finder windows
# For other paths, use `PfLo` and `file:///full/path/here/`
defaults write com.apple.finder NewWindowTarget -string "PfHm"

# Customize the favorites
mysides remove Recents
mysides remove Documents
mysides add marcofugaro "file://${HOME}/"
mysides add Code "file://${HOME}/Code"

# Keep folders on top when sorting by name
defaults write com.apple.finder _FXSortFoldersFirst -bool true

# When performing a search, search the current folder by default
defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"

# Disable the warning when changing a file extension
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false

# Remove toolbar title rollover delay
defaults write NSGlobalDomain "NSToolbarTitleViewRolloverDelay" -float "0"

# Avoid creating .DS_Store files on network or USB volumes
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true

# Use column view in all Finder windows by default
# Four-letter codes for the other view modes: `icnv`, `Nlsv `, `glyv`
defaults write com.apple.finder FXPreferredViewStyle clmv

# Sort by kind
/usr/libexec/PlistBuddy -c "Set :StandardViewSettings:IconViewSettings:arrangeBy kind" ~/Library/Preferences/com.apple.finder.plist

# Reset the finder
killall Finder
