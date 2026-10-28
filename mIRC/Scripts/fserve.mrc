
;=============================================================================
; FServe Manager v2.0 - mIRC
; Built-in mIRC FServe + DCC Chat
; Commands: /fserve and /fshelp
;=============================================================================

on *:LOAD:{
  fs.init
  echo -a 3FServe Manager v2.0 loaded. Type /fserve to open the manager.
}

on *:UNLOAD:{
  .timer.FServeAd off
  .timer.FServeStatus off
  unset %fs.active
  unset %fs.pending.*
  echo -a FServe Manager unloaded.
}

;-----------------------------------------------------------------------------
; SETTINGS
;-----------------------------------------------------------------------------

alias -l fs.ini {
  return $scriptdir $+ fserve.ini
}

alias -l fs.init {
  var %ini = $fs.ini
  if (!$isfile(%ini)) {
    writeini $qt(%ini) Settings Homedir $mircdir
    writeini $qt(%ini) Settings MaxGets 3
    writeini $qt(%ini) Settings MaxUsers 5
    writeini $qt(%ini) Settings Trigger !fserve
    writeini $qt(%ini) Settings Channels -
    writeini $qt(%ini) Settings Interval 5
    writeini $qt(%ini) Settings Welcome -
    writeini $qt(%ini) Settings AdMsg -
  }
}

;-----------------------------------------------------------------------------
; MENU
;-----------------------------------------------------------------------------

menu channel,status {
  -
  FServe Manager:/fserve
}

;-----------------------------------------------------------------------------
; COMMANDS
;-----------------------------------------------------------------------------

alias fserve {
  fs.init
  if ($dialog(fs)) dialog -v fs
  else dialog -m fs fs
}

alias fshelp {
  echo -a 12FServe Manager Help
  echo -a /fserve - Open manager
  echo -a /fshelp - Show help
  echo -a Configure the home directory and allowed channels first.
  echo -a Users type the configured trigger in an allowed channel.
  echo -a FServe uses mIRC's built-in DCC chat and file server.
}

;-----------------------------------------------------------------------------
; DIALOG
;-----------------------------------------------------------------------------

dialog fs {
  title "FServe Manager v2.0"
  size -1 -1 340 300
  option dbu
  box "Server Status", 1, 6 6 328 55
  text "Status:", 2, 14 18 40 10
  text "Offline", 3, 55 18 80 10
  text "Users online:", 4, 14 30 55 10
  text "0", 5, 75 30 30 10
  text "Files:", 6, 14 42 40 10
  text "0", 7, 55 42 50 10
  text "Max users:", 8, 160 30 45 10
  text "-", 9, 210 30 30 10
  box "Settings", 10, 6 68 328 170
  text "Home Directory:", 11, 14 82 70 10
  edit "", 12, 14 93 230 12, autohs
  button "Browse...", 13, 248 92 60 13
  text "Max Gets per user:", 14, 14 114 70 10
  edit "", 15, 90 113 30 12, right
  text "Max Users:", 16, 140 114 40 10
  edit "", 17, 185 113 30 12, right
  text "Trigger:", 18, 14 134 40 10
  edit "", 19, 55 133 100 12, autohs
  text "Channels (space separated):", 20, 14 154 120 10
  edit "", 21, 14 165 300 12, autohs
  text "Ad interval (minutes):", 22, 14 186 80 10
  edit "", 23, 100 185 30 12, right
  text "Welcome file (optional):", 24, 14 206 90 10
  edit "", 25, 14 217 230 12, autohs
  button "Browse...", 26, 248 216 60 13
  button "Start Server", 30, 6 248 80 22
  button "Stop Server", 31, 90 248 80 22
  button "Refresh Status", 32, 174 248 70 22
  button "Save Settings", 34, 250 248 70 22
}

;-----------------------------------------------------------------------------
; DIALOG EVENTS
;-----------------------------------------------------------------------------

on *:DIALOG:fs:init:0:{
  fs.init
  did -ra $dname 12 $readini($fs.ini,Settings,Homedir)
  did -ra $dname 15 $readini($fs.ini,Settings,MaxGets)
  did -ra $dname 17 $readini($fs.ini,Settings,MaxUsers)
  did -ra $dname 19 $readini($fs.ini,Settings,Trigger)
  var %chans = $readini($fs.ini,Settings,Channels)
  if (%chans == -) var %chans =
  did -ra $dname 21 %chans
  did -ra $dname 23 $readini($fs.ini,Settings,Interval)
  var %welcome = $readini($fs.ini,Settings,Welcome)
  if (%welcome == -) var %welcome =
  did -ra $dname 25 %welcome
  fs.update.status
}

on *:DIALOG:fs:sclick:13:{
  var %start = $did(fs,12)
  if (!$isdir(%start)) var %start = $mircdir
  var %dir = $sdir(%start,Select FServe Home Directory)
  if (%dir) did -ra fs 12 %dir
}

on *:DIALOG:fs:sclick:26:{
  var %start = $did(fs,25)
  if (!$isfile(%start)) var %start = $mircdir
  var %file = $sfile(%start,Select Welcome Text File)
  if (%file) did -ra fs 25 %file
}

on *:DIALOG:fs:sclick:30:{
  if ($fs.save.settings) fs.start
  fs.update.status
}

on *:DIALOG:fs:sclick:31:{
  fs.stop
  fs.update.status
}

on *:DIALOG:fs:sclick:32:{
  fs.update.status
}

on *:DIALOG:fs:sclick:34:{
  if ($fs.save.settings) echo -a 3FServe settings saved.
  fs.update.status
}

;-----------------------------------------------------------------------------
; SAVE AND VALIDATE SETTINGS
;-----------------------------------------------------------------------------

alias -l fs.save.settings {
  if (!$dialog(fs)) return 0
  var %dir = $did(fs,12)
  var %gets = $did(fs,15)
  var %users = $did(fs,17)
  var %trig = $did(fs,19)
  var %chans = $did(fs,21)
  var %int = $did(fs,23)
  var %welcome = $did(fs,25)
  if (!$isdir(%dir)) {
    echo -a 4FServe: Home directory does not exist.
    return 0
  }
  if ((%gets !isnum) || (%gets < 1) || (%gets > 100)) {
    echo -a 4FServe: Max Gets must be between 1 and 100.
    return 0
  }
  if ((%users !isnum) || (%users < 1) || (%users > 100)) {
    echo -a 4FServe: Max Users must be between 1 and 100.
    return 0
  }
  if ((%int !isnum) || (%int < 1) || (%int > 1440)) {
    echo -a 4FServe: Interval must be between 1 and 1440 minutes.
    return 0
  }
  if ((%trig == $null) || ($chr(32) isin %trig)) {
    echo -a 4FServe: Trigger must be one word.
    return 0
  }
  if ((%welcome != $null) && (!$isfile(%welcome))) {
    echo -a 4FServe: Welcome file does not exist.
    return 0
  }
  var %ini = $fs.ini
  writeini $qt(%ini) Settings Homedir %dir
  writeini $qt(%ini) Settings MaxGets %gets
  writeini $qt(%ini) Settings MaxUsers %users
  writeini $qt(%ini) Settings Trigger %trig
  writeini $qt(%ini) Settings Channels $iif(%chans == $null,-,%chans)
  writeini $qt(%ini) Settings Interval %int
  writeini $qt(%ini) Settings Welcome $iif(%welcome == $null,-,%welcome)
  return 1
}

;-----------------------------------------------------------------------------
; START / STOP
;-----------------------------------------------------------------------------

alias -l fs.start {
  if (!$dialog(fs)) {
    echo -a Open the manager first with /fserve.
    return
  }
  if (!$isdir($readini($fs.ini,Settings,Homedir))) {
    echo -a 4FServe: Invalid home directory.
    return
  }
  set %fs.active 1
  .timer.FServeAd off
  var %int = $calc($readini($fs.ini,Settings,Interval) * 60)
  .timer.FServeAd 0 %int fs.ad
  echo -a 3FServe is online.
  fs.ad
}

alias -l fs.stop {
  unset %fs.active
  unset %fs.pending.*
  .timer.FServeAd off
  echo -a 4FServe stopped.
}

;-----------------------------------------------------------------------------
; STATUS
;-----------------------------------------------------------------------------

alias -l fs.update.status {
  if (!$dialog(fs)) return
  if (%fs.active) did -ra fs 3 3Online
  else did -ra fs 3 4Offline
  did -ra fs 5 $fserve(0)
  did -ra fs 7 $fs.files
  did -ra fs 9 $readini($fs.ini,Settings,MaxUsers)
}

alias -l fs.files {
  var %dir = $readini($fs.ini,Settings,Homedir)
  if (!$isdir(%dir)) return 0
  return $findfile(%dir,*.*,0)
}

alias -l fs.users {
  return $fserve(0)
}

alias -l fs.trigger {
  return $readini($fs.ini,Settings,Trigger)
}

;-----------------------------------------------------------------------------
; CHANNEL TRIGGER
;-----------------------------------------------------------------------------

on *:TEXT:*:#:{
  if (!%fs.active) return
  if ($1 != $fs.trigger) return
  var %chans = $readini($fs.ini,Settings,Channels)
  if ((%chans == -) || (%chans == $null)) return
  if (!$istok(%chans,$chan,32)) return
  fs.connect $nick
}

;-----------------------------------------------------------------------------
; START A REAL BUILT-IN FSERVE SESSION
;-----------------------------------------------------------------------------


;=========================================================
; DCC CHAT CONNECTOR
; Trigger: !fserve in an allowed channel
;=========================================================

alias -l fs.connect {
  var %nick = $1
  if (%nick == $null) return
  if (!%fs.active) return
  if (%nick == $me) {
    echo -a 4FServe: You cannot open a DCC chat with yourself.
    return
  }
  if ($window(= $+ %nick)) {
    .notice %nick You already have a DCC chat window open.
    return
  }
  if (%fs.busy. [ $+ [ %nick ] ]) {
    .notice %nick A DCC chat request is already pending.
    return
  }
  set -u60 %fs.busy. [ $+ [ %nick ] ] 1
  echo -a 3DCC Chat: Sending chat request to %nick
  dcc chat %nick
  .timer 1 60 fs.dcc.timeout %nick
}

alias -l fs.dcc.timeout {
  var %nick = $1
  unset %fs.busy. [ $+ [ %nick ] ]
  if (!$window(= $+ %nick)) {
    echo -a 4DCC Chat: No chat window detected for %nick after 60 seconds.
  }
}

;-----------------------------------------------------------------------------
; ADVERTISEMENT
;-----------------------------------------------------------------------------

alias -l fs.connect {
  var %nick = $1
  if (%nick == $null) return
  if (!%fs.active) return
  var %maxu = $readini($fs.ini,Settings,MaxUsers)
  var %gets = $readini($fs.ini,Settings,MaxGets)
  var %dir = $readini($fs.ini,Settings,Homedir)
  var %welcome = $readini($fs.ini,Settings,Welcome)
  if (!$isdir(%dir)) {
    echo -a 4FServe: Home directory does not exist.
    return
  }
  if ($fserve(%nick)) {
    .notice %nick You already have an open FServe session.
    return
  }
  if (%fs.busy. [ $+ [ %nick ] ]) {
    .notice %nick Your FServe request is already being processed.
    return
  }
  if ($fserve(0) >= %maxu) {
    .notice %nick FServe is full. Please try again later.
    return
  }
  set -u15 %fs.busy. [ $+ [ %nick ] ] 1

  if ((%welcome != -) && ($isfile(%welcome))) {
    fserve %nick %gets $qt(%dir) $qt(%welcome)
  }
  else {
    fserve %nick %gets $qt(%dir)
  }
  .timer 1 3 fs.check %nick
}

alias -l fs.check {
  var %nick = $1
  if (%nick == $null) return
  if ($fserve(%nick)) {
    echo -a 3FServe: FServe session detected for %nick
  }
  else {
    echo -a 4FServe: No FServe session detected for %nick
    echo -a 4Check the /fserve command syntax and your mIRC version.
  }
  unset %fs.busy. [ $+ [ %nick ] ]
  fs.update.status
}


alias -l fs.ad {
  if (!%fs.active) return
  var %chans = $readini($fs.ini,Settings,Channels)
  if ((%chans == -) || (%chans == $null)) return
  var %msg = $readini($fs.ini,Settings,AdMsg)
  if ((%msg == $null) || (%msg == -)) {
    var %msg = FServe Online - Files: $fs.files - Users: $fs.users / $readini($fs.ini,Settings,MaxUsers) - Type $fs.trigger to connect
  }
  var %i = 1
  while ($gettok(%chans,%i,32)) {
    var %chan = $v1
    if ($me ison %chan) msg %chan %msg
    inc %i
  }
}


;=========================================================
; FServe DCC CHAT COMMANDS
; Compatible target: mIRC 7.84
;
; Commands:
; help, info, list, cd, get, read, bye, exit
;=========================================================

;---------------------------------------------------------
; WELCOME MESSAGE - ONLY AFTER DCC CHAT OPENS
;---------------------------------------------------------

on *:OPEN:=:{
  var %nick = $nick
  if (%nick == $null) return
  var %root = $readini($fs.ini,Settings,Homedir)
  if (!$isdir(%root)) {
    msg =$nick DCC Share: The share directory is unavailable.
    return
  }
  if ($right(%root,1) != $chr(92)) %root = %root $+ $chr(92)
  set %dchat.root. [ $+ [ %nick ] ] %root
  set %dchat.path. [ $+ [ %nick ] ] %root
  .timer 1 2 dchat.welcome %nick
}

alias -l dchat.welcome {
  var %nick = $1
  if (%nick == $null) return
  if (!$chat(%nick)) return
  msg = $+ %nick ----------------------------------------
  msg = $+ %nick Welcome to the DCC File Share!
  msg = $+ %nick Type HELP to see all available commands.
  msg = $+ %nick ----------------------------------------
  msg = $+ %nick Commands: HELP, INFO, LIST, CD, GET, READ, BYE
  msg = $+ %nick Use LIST to show files and directories.
  msg = $+ %nick Use GET filename to request a file.
  msg = $+ %nick ----------------------------------------
}

;---------------------------------------------------------
; DCC CHAT COMMAND HANDLER
;---------------------------------------------------------

on *:CHAT:*:{
  if ($1 == $null) return
  var %cmd = $lower($1)
  var %nick = $nick
  var %path = %dchat.path. [ $+ [ %nick ] ]
  var %root = %dchat.root. [ $+ [ %nick ] ]
  if (%path == $null) {
    msg =$nick Share session not initialized. Reopen the DCC chat.
    return
  }
  ; HELP
  if (%cmd == help) {
    msg =$nick -------- DCC SHARE HELP --------
    msg =$nick HELP              - Show this help
    msg =$nick INFO              - Show session information
    msg =$nick LIST              - List files and folders
    msg =$nick CD folder         - Enter a subfolder
    msg =$nick CD ..             - Go up one folder
    msg =$nick GET filename      - Request a file
    msg =$nick READ filename     - Read a text file
    msg =$nick BYE / EXIT        - Close the DCC chat
    msg =$nick --------------------------------
    return
  }
  ; INFO
  if (%cmd == info) {
    msg =$nick DCC File Share
    msg =$nick Your nickname: %nick
    msg =$nick Current directory: %path
    msg =$nick Files in this folder: $findfile(%path,*.*,0,1)
    msg =$nick --------------------------------
    return
  }
  ; LIST
  if (%cmd == list) {
    msg =$nick Directory listing:
    var %i = 1
    var %count = 0
    while (%i <= 100) {
      var %entry = $findfile(%path,*.*, %i,1)
      if (%entry == $null) break
      var %name = $nopath(%entry)
      msg =$nick %name
      inc %count
      inc %i
    }
    if (%count == 0) msg =$nick No files found in this folder.
    if (%count >= 100) msg =$nick Listing limited to 100 entries.
    return
  }
  ; CD
  if (%cmd == cd) {
    var %folder = $2-
    if (%folder == $null) {
      msg =$nick Usage: CD folder
      return
    }
    if (%folder == ..) {
      if ($lower(%path) == $lower(%root)) {
        msg =$nick You are already in the root directory.
        return
      }
      var %parent = $nofile(%path $+ x)
      if ($lower(%parent) == $lower(%root)) {
        set %dchat.path. [ $+ [ %nick ] ] %root
      }
      elseif ($left($lower(%parent),$len(%root)) == $lower(%root)) {
        set %dchat.path. [ $+ [ %nick ] ] %parent
      }
      else {
        msg =$nick Access denied.
        return
      }
      msg =$nick Current directory: %dchat.path. [ $+ [ %nick ] ]
      return
    }
    ; Only allow a single directory name, not a path.
    if (($chr(92) isin %folder) || ($chr(47) isin %folder) || ($chr(58) isin %folder) || (%folder == .) || (%folder == ..)) {
      msg =$nick Invalid folder name.
      return
    }
    var %newpath = %path $+ %folder
    if ($right(%path,1) != $chr(92)) var %newpath = %path $+ $chr(92) $+ %folder
    if (!$isdir(%newpath)) {
      msg =$nick Directory not found.
      return
    }
    if ($left($lower(%newpath),$len(%root)) != $lower(%root)) {
      msg =$nick Access denied.
      return
    }
    if ($right(%newpath,1) != $chr(92)) var %newpath = %newpath $+ $chr(92)
    set %dchat.path. [ $+ [ %nick ] ] %newpath
    msg =$nick Current directory: %newpath
    return
  }
  ; GET
  if (%cmd == get) {
    var %file = $2-
    if (%file == $null) {
      msg =$nick Usage: GET filename
      return
    }
    if (($chr(92) isin %file) || ($chr(47) isin %file) || ($chr(58) isin %file) || (%file == .) || (%file == ..)) {
      msg =$nick Invalid filename.
      return
    }
    var %full = %path $+ %file
    if ($right(%path,1) != $chr(92)) var %full = %path $+ $chr(92) $+ %file
    if (!$isfile(%full)) {
      msg =$nick File not found.
      return
    }
    msg =$nick Sending file: %file
    dcc send %nick $qt(%full)
    return
  }
  ; READ - TEXT FILES ONLY
  if (%cmd == read) {
    var %file = $2-
    if (%file == $null) {
      msg =$nick Usage: READ filename.txt
      return
    }
    if (($chr(92) isin %file) || ($chr(47) isin %file) || ($chr(58) isin %file) || (%file == .) || (%file == ..)) {
      msg =$nick Invalid filename.
      return
    }
    if ($gettok(%file,$numtok(%file,46),46) != txt) {
      msg =$nick Only TXT files can be read.
      return
    }
    var %full = %path $+ %file
    if ($right(%path,1) != $chr(92)) var %full = %path $+ $chr(92) $+ %file
    if (!$isfile(%full)) {
      msg =$nick File not found.
      return
    }
    msg =$nick Reading first 20 lines of %file:
    var %i = 1
    while (%i <= 20) {
      var %line = $read(%full,%i)
      if (%line == $null) break
      msg =$nick %line
      inc %i
    }
    msg =$nick End of file preview.
    return
  }
  ; BYE / EXIT
  if ((%cmd == bye) || (%cmd == exit)) {
    msg =$nick Goodbye!
    .timer 1 2 dchat.close %nick
    return
  }
  msg =$nick Unknown command. Type HELP for a list of commands.
}

;---------------------------------------------------------
; CLOSE SESSION
;---------------------------------------------------------

alias -l dchat.close {
  var %nick = $1
  if (%nick == $null) return
  unset %dchat.root. [ $+ [ %nick ] ]
  unset %dchat.path. [ $+ [ %nick ] ]
  if ($chat(%nick)) close -c = $+ %nick
}

on *:CLOSE:=:{
  unset %dchat.root. [ $+ [ $nick ] ]
  unset %dchat.path. [ $+ [ $nick ] ]
}
