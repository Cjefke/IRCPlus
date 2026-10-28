; =====================================================================
; IRCPlus MP3 Player - repaired for mIRC 7.84
; Open with: /mpn | Configure announcement channels in Settings (comma-separated)
; =====================================================================

alias mpn {
  if ($dialog(mpnew)) dialog -v mpnew
  else dialog -md mpnew mpnew
}

alias mp_mini {
  if ($dialog(mini_mpnew)) dialog -v mini_mpnew
  else dialog -md mini_mpnew mini_mpnew
}

alias mp_settings {
  if ($dialog(settings_mpnew)) dialog -v settings_mpnew
  else dialog -md settings_mpnew settings_mpnew
}

; ----------------------------- Main dialog ----------------------------
dialog mpnew {
  title "IRCPlus MP3 Player"
  size -1 -1 370 270
  option dbu
  box "PLAYLIST", 100, 6 6 226 142
  list 2, 12 18 214 122, size vsbar extsel
  box "VOLUME", 101, 238 6 42 142
  scroll "", 13, 252 20 12 112, range 0 65535 vertical
  button "Choose folder", 19, 286 12 76 16
  button "Refresh", 21, 286 32 76 16
  button "Mini player", 34, 286 52 76 16
  button "Settings", 41, 286 72 76 16
  button "Close", 11, 286 124 76 16
  box "NOW PLAYING", 102, 6 154 356 48
  text "Nothing playing", 31, 14 166 340 12
  text "00:00 / 00:00", 32, 14 181 90 12
  scroll "", 4, 110 181 244 10, range 0 1000
  box "PLAYBACK", 103, 6 207 226 43
  button "|< Previous", 25, 12 222 52 17
  button "Play", 5, 70 222 42 17
  button "Stop", 6, 116 222 42 17
  button "Next >|", 24, 162 222 62 17
  check "Random", 23, 240 211 62 12
  check "Repeat / continue", 27, 240 229 116 12
  text "IRCPlus MP3 Player  |  by Cjefke", 26, 6 254 356 10, center
}

; ----------------------------- Mini dialog ----------------------------
dialog mini_mpnew {
  title "IRCPlus MP3 Mini Player"
  size -1 -1 250 112
  option dbu
  text "Nothing playing", 10, 6 4 238 12, center
  button "|<", 5, 6 22 34 17
  button "Play", 2, 44 22 42 17
  button "Stop", 4, 90 22 42 17
  button ">>|", 3, 136 22 38 17
  button "Full player", 6, 180 22 64 17
  text "00:00 / 00:00", 11, 6 43 238 12, center
  list 1, 6 59 238 46, size vsbar
}

; ----------------------------- Settings -------------------------------
dialog settings_mpnew {
  title "MP3 Player Settings | Output Presets"
  size -1 -1 270 278
  option dbu
  box "Playback notifications", 10, 6 6 258 62
  check "Show mIRC tip when a track starts", 1, 12 18 238 12
  check "Send track message to allowed channels", 5, 12 34 238 12
  check "Use ASCII-style text", 7, 12 50 238 12
  box "Channel allow-list", 9, 6 72 258 56
  text "Channels to announce in (comma-separated):", 11, 12 82 244 12
  edit "", 6, 12 96 244 18, autohs
  text "Example: #IRCPlus,#music  |  Only these joined channels receive messages.", 12, 12 115 244 12
  text "Message format:", 3, 12 136 100 12
  edit "Now playing: [SONG] - Length: [LENGTH]", 2, 12 150 244 20, autohs
  text "Tags: [SONG], [LENGTH], [NICK].", 8, 12 173 244 16
  box "Old-school output presets", 13, 6 192 258 48
  combo 14, 12 205 166 90, drop
  button "Use preset", 15, 184 205 72 17
  text "Placeholders: [SONG] [LENGTH] [NICK]", 16, 12 226 244 10
  button "Save && Close", 4, 94 248 82 17
}

; ----------------------------- Lifecycle ------------------------------
on *:START: {
  .timerMPUpdate off
  .timerMPSeek off
}

on *:UNLOAD: {
  .timerMPUpdate off
  .timerMPSeek off
  splay stop
  unset %mp.*
}

on *:dialog:mpnew:init:0: {
  did -ra mpnew 31 Nothing playing
  did -ra mpnew 32 00:00 / 00:00
  did -c mpnew 4 0
  if (%mp.rand == on) did -c mpnew 23
  if (%mp.continue == on) did -c mpnew 27
  if (!$readini(mp3player.ini,settings,directory)) {
    if ($isdir($mircdir $+ sounds)) set %mp.dir $mircdir $+ sounds
  }
  else set %mp.dir $readini(mp3player.ini,settings,directory)
  if ($readini(mp3player.ini,settings,format)) set %mp.format $readini(mp3player.ini,settings,format)
  if (%mp.dir) mp_refresh
  did -s mpnew 13 $vol(master)
}

on *:dialog:mpnew:close:*: {
  .timerMPSeek off
  ; Closing the window does not unexpectedly stop the current song.
}

on *:dialog:mpnew:sclick:19: {
  var %dir = $sdir(%mp.dir,Choose the folder containing MP3 files)
  if (%dir) {
    set %mp.dir %dir
    writeini mp3player.ini settings directory %mp.dir
    mp_refresh
  }
}

on *:dialog:mpnew:sclick:21: mp_refresh

on *:dialog:mpnew:sclick:2: {
  if ($did(mpnew,2).sel) set %mp.file $did(mpnew,2).seltext
}

on *:dialog:mpnew:dclick:2: {
  if (!$did(mpnew,2).sel) return
  set %mp.file $did(mpnew,2).seltext
  mp_playselected
}

on *:dialog:mpnew:sclick:5: {
  if ($did(mpnew,5).text == Pause) {
    splay pause
    set %mp.pause on
    did -ra mpnew 5 Resume
    return
  }
  if ($did(mpnew,5).text == Resume) {
    splay resume
    set %mp.pause off
    did -ra mpnew 5 Pause
    return
  }
  if (!$did(mpnew,2).sel) {
    if ($did(mpnew,2).lines < 1) return
    did -c mpnew 2 1
  }
  set %mp.file $did(mpnew,2).seltext
  mp_playselected
}

on *:dialog:mpnew:sclick:6: mp_stop
on *:dialog:mpnew:sclick:11: {
  if ($input(Stop playback before closing?,yn,MP3 Player) == $true) mp_stop
  dialog -x mpnew
}
on *:dialog:mpnew:scroll:13: vol -v $did(13).sel
on *:dialog:mpnew:sclick:23: {
  if (%mp.rand == on) set %mp.rand off
  else set %mp.rand on
}
on *:dialog:mpnew:sclick:27: {
  if (%mp.continue == on) set %mp.continue off
  else set %mp.continue on
}
on *:dialog:mpnew:sclick:24: mp3next
on *:dialog:mpnew:sclick:25: mp3previous
on *:dialog:mpnew:sclick:34: { mp_mini | dialog -x mpnew }
on *:dialog:mpnew:sclick:41: mp_settings
on *:dialog:mpnew:scroll:4: {
  if (!$inmp3) return
  if (!$inmp3.length) return
  .timerMPSeek -m 1 150 splay seek $int($calc(($did(mpnew,4).sel / 1000) * $inmp3.length))
}

; ----------------------------- Mini events ----------------------------
on *:dialog:mini_mpnew:init:0: {
  if (%mp.file) did -ra mini_mpnew 10 $remove(%mp.file,.mp3)
  else did -ra mini_mpnew 10 Nothing playing
  if (%mp.dir) mp_refreshmini
  mp_update_display
}
on *:dialog:mini_mpnew:sclick:2: {
  if ($did(mini_mpnew,2).text == Pause) {
    splay pause | set %mp.pause on | did -ra mini_mpnew 2 Resume
  }
  elseif ($did(mini_mpnew,2).text == Resume) {
    splay resume | set %mp.pause off | did -ra mini_mpnew 2 Pause
  }
  elseif ($did(mini_mpnew,1).lines > 0) {
    if (!$did(mini_mpnew,1).sel) did -c mini_mpnew 1 1
    set %mp.file $did(mini_mpnew,1,$did(mini_mpnew,1).sel)
    mp_playselected
  }
}
on *:dialog:mini_mpnew:sclick:3: mp3next
on *:dialog:mini_mpnew:sclick:4: mp_stop
on *:dialog:mini_mpnew:sclick:5: mp3previous
on *:dialog:mini_mpnew:sclick:6: { mpn | dialog -x mini_mpnew }
on *:dialog:mini_mpnew:dclick:1: {
  if (!$did(mini_mpnew,1).sel) return
  set %mp.file $did(mini_mpnew,1).seltext
  mp_playselected
}

; ----------------------------- Settings events ------------------------
on *:dialog:settings_mpnew:init:0: {
  if (%mp.tip == on) did -c settings_mpnew 1
  if (%mp.msg == on) did -c settings_mpnew 5
  if (%mp.ascii == on) did -c settings_mpnew 7
  if (%mp.format == $null) set %mp.format Now playing: [SONG] - Length: [LENGTH]
  if (!$isfile(mp3player.ini)) noop
  if (!$readini(mp3player.ini,settings,channels) && %mp.chan) set %mp.channels %mp.chan
  else set %mp.channels $readini(mp3player.ini,settings,channels)
  did -ra settings_mpnew 2 %mp.format
  did -ra settings_mpnew 6 %mp.channels
  did -a settings_mpnew 14 Classic IRC
  did -a settings_mpnew 14 Old-school Talker
  did -a settings_mpnew 14 BBS / ANSI Box
  did -a settings_mpnew 14 Radio DJ
  did -a settings_mpnew 14 Minimal
  did -a settings_mpnew 14 Leetspeak 1337
  did -a settings_mpnew 14 Leetspeak Elite
  did -a settings_mpnew 14 Green Terminal
  did -a settings_mpnew 14 Color Pop
  did -a settings_mpnew 14 Rainbow-ish
  did -a settings_mpnew 14 Cyberpunk
  did -a settings_mpnew 14 Now Spinning
  did -c settings_mpnew 14 1
}
on *:dialog:settings_mpnew:sclick:1: {
  if ($did(settings_mpnew,1).state) set %mp.tip on
  else set %mp.tip off
}
on *:dialog:settings_mpnew:sclick:5: {
  if ($did(settings_mpnew,5).state) set %mp.msg on
  else set %mp.msg off
}
on *:dialog:settings_mpnew:sclick:7: {
  if ($did(settings_mpnew,7).state) set %mp.ascii on
  else set %mp.ascii off
}
on *:dialog:settings_mpnew:sclick:15: {
  var %preset = $did(settings_mpnew,14).sel
  if (%preset == 1) set %mp.format Now playing: [SONG] - Length: [LENGTH]
  elseif (%preset == 2) set %mp.format *** [NICK] is listening to "[SONG]" ([LENGTH])
  elseif (%preset == 3) set %mp.format $+([-- NOW PLAYING --] ,$chr(124), [SONG] ,$chr(124), [LENGTH])
  elseif (%preset == 4) set %mp.format [ON AIR] [SONG] - Runtime [LENGTH]
  elseif (%preset == 5) set %mp.format [SONG] ([LENGTH])
  elseif (%preset == 6) set %mp.format N0W PL4Y1NG: [SONG] // [LENGTH]
  elseif (%preset == 7) set %mp.format $+(3L1T3 M0D3: [SONG],$chr(32),$chr(124),$chr(32),[LENGTH])
  elseif (%preset == 8) set %mp.format $+($chr(3),03,TERMINAL,$chr(3),$chr(32),$chr(124),$chr(32),[SONG],$chr(3),03,$chr(32),$chr(40),[LENGTH],$chr(41))
  elseif (%preset == 9) set %mp.format $+($chr(3),04,NOW PLAYING,$chr(3),$chr(32),$chr(124),$chr(32),$chr(3),12,[SONG],$chr(3),$chr(32),$chr(124),$chr(32),$chr(3),08,[LENGTH],$chr(3))
  elseif (%preset == 10) set %mp.format $+($chr(3),04,[ON AIR],$chr(3),$chr(32),$chr(124),$chr(32),$chr(3),07,[SONG],$chr(3),$chr(32),$chr(124),$chr(32),$chr(3),12,[LENGTH],$chr(3))
  elseif (%preset == 11) set %mp.format $+($chr(3),06,CYBER,$chr(3),$chr(32),$chr(124),$chr(32),$chr(3),10,[SONG],$chr(3),$chr(32),$chr(124),$chr(32),$chr(3),13,[LENGTH],$chr(3))
  elseif (%preset == 12) set %mp.format $+($chr(3),07,NOW SPINNING,$chr(3),$chr(32),$chr(124),$chr(32),[SONG],$chr(32),$chr(40),[LENGTH],$chr(41))
  did -ra settings_mpnew 2 %mp.format
}
on *:dialog:settings_mpnew:sclick:4: {
  set %mp.format $did(settings_mpnew,2).text
  set %mp.channels $remove($did(settings_mpnew,6).text,$chr(32))
  writeini mp3player.ini settings format %mp.format
  writeini mp3player.ini settings channels %mp.channels
  if (%mp.channels) set %mp.chan $gettok(%mp.channels,1,44)
  dialog -x settings_mpnew
}

; ----------------------------- Core aliases ---------------------------
alias mp_refresh {
  if (!$dialog(mpnew)) return
  did -r mpnew 2
  if (%mp.dir && $isdir(%mp.dir)) {
    noop $findfile(%mp.dir,*.mp3,0,1,did -a mpnew 2 $nopath($1-))
  }
  if ($dialog(mini_mpnew)) mp_refreshmini
}

alias mp_refreshmini {
  if (!$dialog(mini_mpnew)) return
  did -r mini_mpnew 1
  if (%mp.dir && $isdir(%mp.dir)) {
    noop $findfile(%mp.dir,*.mp3,0,1,did -a mini_mpnew 1 $nopath($1-))
  }
}

alias mp_playselected {
  if (!%mp.file) return
  if (!$isfile($+(%mp.dir,$iif($right(%mp.dir,1) != \,\),%mp.file))) {
    echo -a [MP3 Player] File not found: %mp.file
    return
  }
  set %mp.path $+(%mp.dir,$iif($right(%mp.dir,1) != \,\),%mp.file)
  splay stop
  splay $qt(%mp.path)
  set %mp.play on
  set %mp.pause off
  set %mp.started $ctime
  ; Remember the channel if playback was started from a channel window.
  if ($chan($active)) set %mp.chan $active
  did -ra mpnew 31 $remove(%mp.file,.mp3)
  did -ra mpnew 5 Pause
  if ($dialog(mini_mpnew)) {
    did -ra mini_mpnew 10 $remove(%mp.file,.mp3)
    did -ra mini_mpnew 2 Pause
  }
  .timerMPUpdate off
  .timerMPUpdate 0 1 mp3update
  mpmsg
  mp_update_display
}

alias mp_stop {
  .timerMPUpdate off
  .timerMPSeek off
  splay stop
  set %mp.play off
  set %mp.pause off
  did -ra mpnew 31 Nothing playing
  did -ra mpnew 32 00:00 / 00:00
  did -c mpnew 4 0
  did -ra mpnew 5 Play
  if ($dialog(mini_mpnew)) {
    did -ra mini_mpnew 10 Nothing playing
    did -ra mini_mpnew 11 00:00 / 00:00
    did -ra mini_mpnew 2 Play
  }
}

alias mp3update {
  if (%mp.play != on) { .timerMPUpdate off | return }
  if (!$inmp3) {
    ; SPLAY may report a brief gap while changing tracks; do not reset the display here.
    return
  }
  var %len = $inmp3.length
  var %pos = $inmp3.pos
  if (%len !isnum 1-) return
  if (%pos !isnum 0-) %pos = 0
  var %pct = $int($calc((%pos / %len) * 1000))
  if (%pct < 0) %pct = 0
  if (%pct > 1000) %pct = 1000
  var %cursec = $int($calc(%pos / 1000))
  var %totsec = $int($calc(%len / 1000))
  var %cur = $+( $base($int($calc(%cursec / 60)),10,10,2),:,$base($calc(%cursec % 60),10,10,2))
  var %tot = $+( $base($int($calc(%totsec / 60)),10,10,2),:,$base($calc(%totsec % 60),10,10,2))
  if ($dialog(mpnew)) {
    did -ra mpnew 32 $+(%cur, / ,%tot)
    did -c mpnew 4 %pct
  }
  if ($dialog(mini_mpnew)) did -ra mini_mpnew 11 $+(%cur, / ,%tot)
}

alias mp_update_display {
  if ($inmp3) mp3update
}

alias mp3next {
  var %total = 0
  var %line = 0
  if ($dialog(mpnew)) {
    %total = $did(mpnew,2).lines
    %line = $did(mpnew,2).sel
  }
  elseif ($dialog(mini_mpnew)) {
    %total = $did(mini_mpnew,1).lines
    %line = $did(mini_mpnew,1).sel
  }
  else return
  if (%total < 1) return
  if (%mp.rand == on) { mp_randplay | return }
  if (%line !isnum 1-) %line = 0
  inc %line
  if (%line > %total) %line = 1
  if ($dialog(mpnew)) {
    did -c mpnew 2 %line
    set %mp.file $did(mpnew,2,%line)
  }
  else {
    did -c mini_mpnew 1 %line
    set %mp.file $did(mini_mpnew,1,%line)
  }
  mp_playselected
}

alias mp3previous {
  var %total = 0
  var %line = 0
  if ($dialog(mpnew)) {
    %total = $did(mpnew,2).lines
    %line = $did(mpnew,2).sel
  }
  elseif ($dialog(mini_mpnew)) {
    %total = $did(mini_mpnew,1).lines
    %line = $did(mini_mpnew,1).sel
  }
  else return
  if (%total < 1) return
  if (%line !isnum 1-) %line = 1
  dec %line
  if (%line < 1) %line = %total
  if ($dialog(mpnew)) {
    did -c mpnew 2 %line
    set %mp.file $did(mpnew,2,%line)
  }
  else {
    did -c mini_mpnew 1 %line
    set %mp.file $did(mini_mpnew,1,%line)
  }
  mp_playselected
}

alias mp_randplay {
  var %total = 0
  if ($dialog(mpnew)) %total = $did(mpnew,2).lines
  elseif ($dialog(mini_mpnew)) %total = $did(mini_mpnew,1).lines
  if (%total < 1) return
  var %line = $rand(1,%total)
  if ($dialog(mpnew)) {
    did -c mpnew 2 %line
    set %mp.file $did(mpnew,2,%line)
  }
  else {
    did -c mini_mpnew 1 %line
    set %mp.file $did(mini_mpnew,1,%line)
  }
  mp_playselected
}

alias mpchannel {
  if (!$1) {
    echo -a [MP3 Player] Usage: /mpchannel #channel
    echo -a [MP3 Player] Current target: $iif(%mp.chan,%mp.chan,not set)
    return
  }
  if (!$chan($1)) {
    echo -a [MP3 Player] You must be joined to $1 first.
    return
  }
  set %mp.chan $1
  echo -a [MP3 Player] Track announcements will be sent to %mp.chan
}

alias mpmsg {
  if (%mp.msg != on && %mp.tip != on) return
  if (%mp.format == $null) set %mp.format Now playing: [SONG] - Length: [LENGTH]
  var %song = $remove(%mp.file,.mp3)
  var %length = $mplength(%mp.path)
  var %msg = $replace(%mp.format,[SONG],%song,[LENGTH],%length,[NICK],$me)
  if (%mp.ascii == on) %msg = $replacecs(%msg,a,4,A,4,e,3,E,3,i,1,I,1,o,0,O,0,s,5,S,5,t,7,T,7)
  if (%mp.msg == on) {
    var %i = 1
    var %sent = 0
    var %total = $numtok(%mp.channels,44)
    while (%i <= %total) {
      var %target = $gettok(%mp.channels,%i,44)
      if (%target != $null) {
        if ($left(%target,1) != $chr(35)) && ($left(%target,1) != &) {
          echo -a [MP3 Player] Skipping invalid channel name: %target
        }
        elseif ($chan(%target)) {
          msg %target %msg
          inc %sent
        }
      }
      inc %i
    }
    if (%sent == 0) echo -a [MP3 Player] No allowed channels are joined. Set the channel allow-list in MP3 Player > Settings.
  }
  if (%mp.tip == on) noop $tip(IRCPlus MP3 Player,Now Playing,%msg,4)
}

alias mplength {
  var %file = $iif($1-,$1-,%mp.path)
  if (!$isfile(%file)) return 00:00
  var %ms = $sound(%file).length
  if (%ms !isnum 1-) return 00:00
  var %sec = $int($calc(%ms / 1000))
  return $+( $base($int($calc(%sec / 60)),10,10,2),:,$base($calc(%sec % 60),10,10,2))
}

on *:MP3END: {
  set %mp.play off
  .timerMPUpdate off
  if (%mp.continue == on) {
    if (%mp.rand == on) mp_randplay
    else mp3next
  }
  else {
    if ($dialog(mpnew)) did -ra mpnew 5 Play
    if ($dialog(mini_mpnew)) did -ra mini_mpnew 2 Play
  }
}

menu channel,menubar {
  -
  MP3 Player
  .Open:/mpn
  .Mini player:/mp_mini
  .Settings:/mp_settings
  -
}
