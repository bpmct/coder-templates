#!/bin/zsh

# must run as sudo
# ref: https://mangolassi.it/topic/19333/create-a-new-user-on-macos-from-the-terminal-command-line
# (only tested on MacOS 10)

# n(previous user)+1
export USER_ID=$(dscl . -list /Users UniqueID| tail -n1 | awk '{ print $2+1 }')
export USER_DISPLAY_NAME="Sally Brown"
export USERNAME="sally"
dscl . -create /Users/$USERNAME RealName $USER_DISPLAY_NAME
dscl . -create /Users/$USERNAME UniqueID $USER_ID
dscl . -create /Users/$USERNAME PrimaryGroupID $USER_ID
dscl . -create /Users/$USERNAME NFSHomeDirectory /Local/Users/$USERNAME
# disable password (this could potentially be a Coder var?)
dscl . -passwd /Users/$USERNAME '*'
# set as admin user
dscl . -append /Groups/admin GroupMembership $USERNAME