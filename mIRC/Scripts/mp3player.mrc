; mIRC MP3 Player v1.0 by Cjefke - Https://IRCPlus.nl

alias mpn { if ($dialog(mpnew)) dialog -v mpnew | else dialog -md mpnew mpnew }
alias mp_mini { if ($dialog(mini_mpnew)) dialog -v mini_mpnew | else dialog -md mini_mpnew mini_mpnew | set %mini_mode 1 }
alias mp_settings { if ($dialog(settings_mpnew)) dialog -v settings_mpnew | else dialog -md settings_mpnew settings_mpnew }
alias mp_lyrics { if ($dialog(lyrics_mpnew)) dialog -v lyrics_mpnew | else dialog -md lyrics_mpnew lyrics_mpnew }

dialog mpnew {
  title "IRCPlus MP3 Player v1.2"
  size -1 -1 300 230
  option dbu

  ; Playlist
  box "Playlist",1,5 5 180 110
  list 2,10 15 170 90,size extsel

  ; Volume
  box "Volume",12,190 5 35 110
  scroll "",13,202 15 10 80,range 0 65535

  ; Buttons right
  button "Close",11,235 15 55 12
  button "Refresh",21,235 32 55 12
  button "Mini Mode",34,235 49 55 12
  button "MP3 Dir",19,235 66 55 12
  button "Settings",41,235 83 55 12

  ; Play Modes
  box "Play Modes",28,5 120 95 40
  check "Random Play",23,12 133 75 10
  check "Continuous Play",27,12 148 85 10

  ; Now Playing
  box "Now Playing",30,110 120 180 40
  text "Nothing playing...",31,118 135 160 10
  scroll "",4,118 155 160 8,range 0 500

  ; Controls
  box "Controls",3,5 165 95 45
  button "Play",5,12 178 35 12
  button "Stop",6,55 178 35 12
  button "Previous",25,12 195 35 12
  button "Next",24,55 195 35 12

  ; Message Settings
  box "Message Format",14,110 165 180 45
  edit "Now playing: <song> - Length: <length>",15,118 180 160 22,multi autohs autovs

  text "IRCPlus MP3 Player - Made by Cjefke",26,110 215 180 8,center
}

dialog mini_mpnew {
  title "Mini - MP3 Player"
  size -1 -1 146 27
  option dbu
  list 1, 31 3 82 11, size vsbar
  button "Play", 2, 114 2 16 12
  button "Next", 3, 130 2 16 12
  button "Stop", 4, 17 2 16 12
  button "Prev", 5, 2 2 15 12
  button "MP3 Player", 6, 50 16 37 10
}

dialog settings_mpnew {
  title "MP3 Player - Settings"
  size -1 -1 136 117
  option dbu
  check "Use $tip when playing songs", 1, 4 2 79 10
  list 2, 2 67 126 32, size vsbar
  text "Please select which type of format you want used when playing a song.", 3, 2 51 126 15
  button "Save && Return", 4, 46 102 39 12, flat
  check "Activate Messages", 5, 4 39 78 10
  check "Post info online", 6, 4 14 78 10
  check "Use Ascii Characters", 7, 4 27 61 10
}

dialog lyrics_mpnew {
  title "MP3 Player - Lyrics"
  size -1 -1 236 176
  option dbu
  edit "", 1, 2 26 230 148, read multi return autohs autovs
  text "Lyrics Page using http://www.metrolyrics.com/ for lyrics. Any wrong lyrics or missing lyrics have nothing to do with the actual MP3 Player", 2, 10 4 216 16
}

;Dialog Activated.
on *:dialog:mpnew:init:0: {
  did -ra mpnew 31 Nothing playing...
  if (%mp.pause == 1) {
    did -r mpnew 5
    did -a mpnew 5 Play
  }
  set %mp.format $did(15)
  if (%mp.rand == On) {
    did -c mpnew 23
  }
  if (%mp.continue == On) {
    did -c mpnew 27
  }
  if ($readini(mp3player.ini,settings,directory)) {
    set %mp.dir $readini(mp3player.ini,settings,directory)
  }
  did -ra mpnew 19 MP3 Dir

  if (%mp.dir != $null) {
    did -r mpnew 2
    set %mp.found $findfile(%mp.dir,*.mp3,0,1,did -a mpnew 2 $nopath($1-))
  }
  did -s mpnew 13 $vol(master)
}

;Double Clicking on play list
on *:dialog:mpnew:sclick:2: { set %mp.file $did(2).seltext | set %mp.temp %mp.dir $+ %mp.file | set %mp.bitrate $mp3(%mp.temp).bitrate | set %mp.size $round($calc($lof(%mp.temp) / 1048576),2) }
on *:dialog:mpnew:dclick:2: { 
  set %mp.file $did(2).seltext
  set %mp.temp %mp.dir $+ %mp.file
  set %mp.bitrate $sound(%mp.temp).bitrate 
  set %mp.length $mplength 
  set %mp.size $round($calc($lof(%mp.temp) / 1048576),2) 
  splay %mp.dir $+ %mp.file
  set %mp.pause 0 
  did -r mpnew 5 
  did -a mpnew 5 Pause 
  set %mp.format $did(15) 
  set %mp.chan $active
  set %mp.chan $active
  mpmsg
}

on *:dialog:mpnew:sclick:41:{
  $mp_settings
}

alias 1 { halt | haltdef }
;Rewind & Fastforward
on *:dialog:mpnew:scroll:4: { 
  .timermp3tseek 1 500 splay seek $int($calc(($did(4).sel / 500) * $inmp3.length)) | .timerpos.update -r
}
;Play Button
on *:dialog:mpnew:sclick:5: {
  if ($did(mpnew,5).text == Play) {
    set %mp.temp %mp.dir $+ %mp.file
    splay %mp.temp
    set %mp.play 1
    set %mp.pause 0
    did -r mpnew 5
    did -a mpnew 5 Pause
    set %mp.format $did(15)
    set %mp.length $mplength
    set %mp.chan $active
    mpmsg
  }
  elseif ($did(mpnew,5).text == Resume) {
    if (%mp.play == 0) { halt }
    elseif (%mp.pause == 1) {
      splay resume
      set %mp.pause 0
      did -r mpnew 5
      did -a mpnew 5 Pause
    }
  }
  elseif ($did(mpnew,5).text == Pause) {
    if ((%mp.play == 1) && (%mp.pause == 0)) {
      splay pause
      set %mp.pause 1
      did -r mpnew 5
      did -a mpnew 5 Resume
    }
  }
}

;Stop Button
on *:dialog:mpnew:sclick:6: { splay stop | set %mp.play 0 | set %mp.pause 0 | did -r mpnew 5 | did -a mpnew 5 Play }

;Close Button
on *:dialog:mpnew:sclick:11: { if ($input(Do you want the song to stop also?,n,End Song,,) == $true) { $mpclose | dialog -x mpnew mpnew } | else { dialog -x mpnew mpnew } }

;Volume Scroller
on *:dialog:mpnew:scroll:13: { vol -v $did(13).sel }

;MP3 Dir Button
on *:dialog:mpnew:sclick:19:{ 
  var %dir = $sdir="Mp3 directory" c:
  if (%dir != $null) {
    set %mp.dir %dir
    writeini mp3player.ini settings directory %mp.dir
    did -ra mpnew 19 $nopath(%mp.dir)
    did -r mpnew 2
    set %mp.found $findfile(%mp.dir,*.mp3,0,1,did -a mpnew 2 $nopath($1-))
  }
}

;Randomnize Playing
on *:dialog:mpnew:sclick:23:{
  if (%mp.rand == On) {
    set %mp.rand Off
    did -u mpnew 23
  }
  else {
    set %mp.rand On
    did -c mpnew 23
  }
}

;Next Song Button
on *:dialog:mpnew:sclick:24:{
  if (%mp.rand == On) {
    randplay
  }
  else {
    mp3next
  }
}

;Previous Song Button
on *:dialog:mpnew:sclick:25: { $soundprevious }

;Continuous Play
on *:dialog:mpnew:sclick:27:{
  if (%mp.continue == On) {
    set %mp.continue Off
    did -u mpnew 27
  }
  else {
    set %mp.continue On
    did -c mpnew 27
  }
}

on *:dialog:mpnew:sclick:21:{
  if (%mp.dir != $null) {
    did -r mpnew 2
    set %mp.found $findfile(%mp.dir, *.mp3,0,1,did -a mpnew 2 $nopath($1-))
  }
}

;Call the Mini Mode up :)
on *:dialog:mpnew:sclick:34: { mp_mini | dialog -x mpnew mpnew }

;Menu and its Items
;Set Directory
on *:dialog:mpnew:menu:36: { did -r mpnew 2 | set %mp.dir $sdir="Mp3 directory" c: | did -o mpnew 13 1 %mp.dir | set %mp.found $findfile(%mp.dir, *.mp3,0,1,did -a mpnew 2 $nopath($1-)) | did -o mpnew 9 1 %mp.found }

;Exit MP3 Player
on *:dialog:mpnew:menu:38: { dialog -x mpnew mpnew }

;Launch Mini Mode
on *:dialog:mpnew:menu:40: { mp_mini | dialog -x mpnew mpnew }

;Launch Setting Window
on *:dialog:mpnew:menu:41: { mp_settings }

;When MP3 Player Finishes, play new Song
on *:MP3END: {
  if (%mp.continue == On) {
    set %mp.play 1

    if (%mp.rand == On) {
      randplay
    }
    else {
      mp3next
    }
  }
}

;When MP3 Player Exits, unset some stuff
on *:dialog:mpnew:close:*: { $mpclose }

;When the script is unloaded, auto unset all variables
on *:UNLOAD: unset %mp.*

;Now we start the coding for the mini MP3 Player Viewer
;When the dialog is opened
on *:dialog:mini_mpnew:init:0: set %mp.found $findfile(%mp.dir, *.mp3,0,1,did -a mini_mpnew 1 $nopath($1-))

;Single Click a Song - Set stuff, don't play although
on *:dialog:mini_mpnew:sclick:1: {
  set %mp.file $did(1).seltext 
  set %mp.temp %mp.dir $+ %mp.file
  set %mp.bitrate $sound(%mp.temp).bitrate
  set %mp.size $round($calc($lof(%mp.temp) / 1048576),2)
}
;Double click a song - set stuff, play song
on *:dialog:mini_mpnew:dclick:1: {
  set %mp.file $did(1).seltext
  set %mp.temp %mp.dir $+ %mp.file
  set %mp.bitrate $sound(%mp.temp).bitrate
  set %mp.length $mplength
  set %mp.size $round($calc($lof(%mp.temp) / 1048576),2)
  splay %mp.dir $+ %mp.file
  set %mp.play 1
  set %mp.pause 0
  set %mp.chan $active
  mpmsg
}

;Play Song.
on *:dialog:mini_mpnew:sclick:2: {
  set %mp.temp %mp.dir $+ %mp.file
  splay %mp.temp
  set %mp.play 1
  set %mp.pause 0
  set %mp.length $mplength
  mpmsg
}

;New Song
on *:dialog:mini_mpnew:sclick:3: { $soundnext }

;Stop Song
on *:dialog:mini_mpnew:sclick:4: { splay stop }

;Previous Song
on *:dialog:mini_mpnew:sclick:5: { $soundprevious }

;Return to Full MP3 Player
on *:dialog:mini_mpnew:sclick:6: { $mpn | dialog -x mini_mpnew mini_mpnew }

on *:dialog:settings_mpnew:init:0: {
  if (%mp.tip == On) { did -c settings_mpnew 1 }
  if (%mp.msg == On) { did -c settings_mpnew 5 }
  if (%mp.online == On) { did -c settings_mpnew 6 }
  if (%mp.ascii == On) { did -c settings_mpnew 7 }
  var %formats = echo,msg,me,amsg,ame
  tokenize 44 %formats
  did -a settings_mpnew 2 $*
  var %i = $findtok(%formats,%mp.mfor,44)
  if (%i) {
    did -c settings_mpnew 2 %i
  }
  else {
    set %mp.mfor me
    did -c settings_mpnew 2 3
  }
}

on *:dialog:settings_mpnew:sclick:1: { if (%mp.tip == On) { set %mp.tip Off } | else set %mp.tip On }
on *:dialog:settings_mpnew:sclick:2: { set %mp.mfor $did(2).seltext }
on *:dialog:settings_mpnew:sclick:4: { dialog -x settings_mpnew settings_mpnew }
on *:dialog:settings_mpnew:sclick:5: { if (%mp.msg == On) { set %mp.msg Off } | else { set %mp.msg On } }
on *:dialog:settings_mpnew:sclick:6: { if (%mp.online == On) { set %mp.online Off } | else { set %mp.online On } }
on *:dialog:settings_mpnew:sclick:7: { if (%mp.ascii == On) { set %mp.ascii Off } | else { set %mp.ascii On } }

alias mpclose {
  set %mp.play 0
  .timermp3Update Off
  splay stop
}
alias mplength {
  var %mp.len $int($calc($sound(%mp.temp).length / 1000))
  var %mp.min $int($calc(%mp.len / 60))
  var %mp.sec $calc(%mp.len - (%mp.min * 60))
  if (%mp.min < 10) { set %mp.min 0 $+ %mp.min }
  if (%mp.sec < 10) { set %mp.sec 0 $+ %mp.sec }
  set %mp.len %mp.min $+ : $+ %mp.sec
  return %mp.len
}

alias F3 { $sounddetermine }

alias mp3determine {
  if (%mp.rand == On) {
    randplay
  }
  else {
    mp3next
  }
}

alias randplay {
  if (!$dialog(mpnew)) { halt }

  var %total $did(mpnew,2).lines
  if (%total == 0) { halt }

  var %random $rand(1,%total)

  set %mp.file $did(mpnew,2,%random).text
  set %mp.temp %mp.dir $+ %mp.file

  splay %mp.temp

  did -c mpnew 2 %random

  set %mp.play 1
  set %mp.pause 0
  set %mp.length $mplength

  did -r mpnew 5
  did -a mpnew 5 Pause
  set %mp.chan $active

  mpmsg
}

alias mp3next {
  if (%mp.play == 0) { halt }
  if (%mp.play == 1) {
    if (($dialog(mpnew)) && (!$dialog(mini_mpnew))) {
      var %line $did(mpnew,2).sel
      if (!%line) { set %line 1 }
      if (%line >= $did(mpnew,2).lines) {
        set %line 0
      }
      inc %line
      splay $+(%mp.dir,$did(mpnew,2,%line))
      did -c mpnew 2 %line
      set %mp.file $did(mpnew,2,%line)
      did -r mpnew 5
      did -a mpnew 5 Pause
      set %mp.format $did(mpnew,15)
    }
    set %mp.play 1
    set %mp.pause 0
    set %mp.length $mplength
    mpmsg
  }
}

alias mp3previous {
  if (%mp.play == 0) { halt }
  elseif (%mp.play == 1) {
    if (($dialog(mpnew)) && (!$dialog(mini_mpnew))) {
      var %line $did(mpnew,2).sel
      splay $+(%mp.dir,$did(mpnew,2, $calc(%line - 1)))
      did -c mpnew 2 $calc(%line - 1)
      set %mp.file $did(mpnew,2, $calc(%line - 1))
      did -r mpnew 5
      did -a mpnew 5 Pause
      set %mp.format $did(mpnew,15)
    }
    elseif ((!$dialog(mpnew)) && ($dialog(mini_mpnew))) {
      var %line $did(mini_mpnew,1).sel
      splay $+(%mp.dir,$did(mini_mpnew,1, $calc(%line - 1)))
      did -c mini_mpnew 1 $calc(%line - 1)
      set %mp.file $did(mini_mpnew,1, $calc(%line - 1))
    }
    set %mp.play 1
    set %mp.pause 0
    set %mp.length $mplength
    mpmsg
  }
}

alias mp3shuffle {
  if (%mp.play == 0) { halt }
  elseif (%mp.play == 1) {
    if ($dialog(mpnew)) {
      var %line $did(mpnew,2).sel
      splay $+(%mp.dir,$did(mpnew,2, $calc(%line + 1)))
      did -c mpnew 2 $calc(%line + 1)
      set %mp.file $did(mpnew,2, $calc(%line + 1))
      did -r mpnew 5
      did -a mpnew 5 Pause
      set %mp.format $did(mpnew,15)
    }
    elseif ($dialog(mini_mpnew)) {
      var %line $did(mini_mpnew,1).sel
      splay $+(%mp.dir,$did(mini_mpnew,1, $calc(%line + 1)))
      did -c mini_mpnew 1 $calc(%line + 1)
      set %mp.file $did(mini_mpnew,1, $calc(%line + 1))
    }
    set %mp.play 1
    set %mp.pause 0
    set %mp.length $mplength
    mpmsg
  }
}

alias mp3update {
  if ($dialog(mpnew)) {
    if (%mp.play == 1) {
      if ($inmp3.length) {
        did -c mpnew 4 $calc(($inmp3.pos / $inmp3.length) * 500)
      }
    }
    else {
      .timermp3Update off
    }
  }
  else {
    .timermp3Update off
  }
}

alias mpmsg {
  if (%mp.online == On) { $soundwrite_online }
  if (!$dialog(mini_mpnew)) { .timermp3Update -o 1 10 mp3update }
  if (%mp.mfor == $null) { echo -a Please select which type of format you want to use | mp_settings }
  else {
    if (%mp.format != $null) {
      set %mp.song $remove(%mp.file,.mp3)
      did -ra mpnew 31 $replace(%mp.file,.mp3,)
      set %mp.song $replace(%mp.format,<song>,%mp.song,<length>,%mp.length)
      if (%mp.ascii == On) { set %mp.song $replacecs(%mp.song,a,?,A,?,b,?,B,?,c,?,C,?,d,?,D,?,e,?,E,?,f,?,F,?,i,?,I,?,l,?,L,?,n,?,N,?,o,?,O,?,p,?,P,?,q,?,Q,?,r,?,R,?,s,?,S,?,u,?,U,?,x,?,X,?,y,?,Y,?,!,?,?,?,>,?,<,?,2,?,3,?,half,?,fourth,?,/,?,.,?,ae,?,tm,?,TM,?) }
      if (%mp.msg == On) {
        if (%mp.mfor == echo) { echo %mp.chan %mp.song }
        elseif (%mp.mfor == say) { msg %mp.chan %mp.song }
        elseif (%mp.mfor == me) { 
          .describe %mp.chan %mp.song
          echo -t %mp.chan $IRCPlus.FormatAction(%mp.chan,$me,%mp.song)
        }
        elseif (%mp.mfor == amsg) { amsg %mp.song }
        elseif (%mp.mfor == ame) { ame %mp.song }
      }
    }
    else {
      set %mp.song $remove(%mp.file,.mp3)
      set %mp.song $replace(%mp.format,<song>,%mp.song,<length>,%mp.length)
      if (%mp.ascii == On) { set %mp.song $replacecs(%mp.song,a,?,A,?,b,?,B,?,c,?,C,?,d,?,D,?,e,?,E,?,f,?,F,?,i,?,I,?,l,?,L,?,n,?,N,?,o,?,O,?,p,?,P,?,q,?,Q,?,r,?,R,?,s,?,S,?,u,?,U,?,x,?,X,?,y,?,Y,?,!,?,?,?,>,?,<,?,2,?,3,?,half,?,fourth,?,/,?,.,?,ae,?,tm,?,TM,?) }
      if (%mp.mfor == echo) { echo %mp.chan %mp.song }
      elseif (%mp.mfor == say) { msg %mp.chan %mp.song }
      elseif (%mp.mfor == me) { 
        .describe %mp.chan %mp.song
        echo -t %mp.chan $IRCPlus.FormatAction(%mp.chan,$me,%mp.song)
      }
      elseif (%mp.mfor == amsg) { amsg %mp.song }
      elseif (%mp.mfor == ame) { ame %mp.song }
    }
  }
  if (%mp.tip == On) { $tip(IRCPlus MP3 Player,IRCPlus MP3 Player,$replace(%mp.format,<song>,$remove(%mp.file,.mp3),<length>,%mp.length),5,,,,) }
}

menu channel,menubar {
  -
  MP3 Player:/mpn
  -
}
