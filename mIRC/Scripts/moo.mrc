;=============================================================
; moo script v5.1 (stable neofetch IRC edition)
; Modifyed by Cjefke 2026 Updated 
; Https://IRCPlus.nl - irc.IRCPlus.nl
;=============================================================

alias -l moo.banchans return #windows #linux #help #helpdesk

;-------------------------------------------------------------
; MAIN COMMAND
;-------------------------------------------------------------
on *:text:!moo:#:set %moochan $chan | /moo 
alias moo {
  if (!$1) {
    var %out = $moor
    var %i = 1
    var %line

    while ($gettok(%out,%i,13) != $null) {
      %line = $v1
      if (%line) {
        if ($active == Status Window) echo -a %line
        else {
          msg %moochan %line
        }
      }
      inc %i
    }
    return
  }

  if ($1 == echo) {
    echo -a $moor
    return
  }

  if ($moof($1)) {
    var %out = $ifmatch
    if ($active == Status Window) echo -gta System: %out
    else { 
      msg %moochan System: %out
    }
  }
}

alias stat moo $1-
alias statself moo echo $1-

;-------------------------------------------------------------
; OUTPUT (NEOFETCH STYLE)
;-------------------------------------------------------------

alias -l moor {

  var %os = 🖥
  var %cpu = ⚙
  var %gpu = 🎮
  var %ram = 🧠
  var %disk = 💾
  var %net = 🌐
  var %up = ⏱

  ; LINE 1
  var %l1 = $+(12,%os, ,$mooi(ostitle), 14| ,10,%cpu, ,$mooi(cpuname), 14| ,13,%gpu, ,$mooi(gfxproc), 14| ,11,%ram, ,$moof(ram))

  ; LINE 2
  var %l2 = $+(10,%disk, ,$moof(hdd))

  ; LINE 3
  var %l3 = $+(11,%net, ,$moof(net), 14| ,13,%up, ,$moof(up))

  return %l1 $+ $chr(13) $+ %l2 $+ $chr(13) $+ %l3
}

;-------------------------------------------------------------
; FIELD FUNCTIONS
;-------------------------------------------------------------

alias moof {

  ; RAM
  if ($1 == ram) {
    var %max = $mooi(rammax), %free = $mooi(ramuse)
    var %used = $calc(%max - %free)
    var %pct = $round($calc(%used / %max * 100),1)
    return $+($round(%used,0),/,%max,MB) $+($chr(40),%pct,%,$chr(41)) $moorambar(%pct)
  }

  ; HDD (FIXED - NO COM, NO CRASHES)

  if ($1 == hdd) {

    var %com = moo.h1, %com2 = moo.h2, %com3 = moo.h3
    var %out, %i = 1

    ; always reset safely
    if ($com(%com)) .comclose %com
    if ($com(%com2)) .comclose %com2
    if ($com(%com3)) .comclose %com3

    ; open WMI
    .comopen %com WbemScripting.SWbemLocator
    var %x = $com(%com,ConnectServer,3,dispatch* %com2)

    var %q = select DeviceID,Size,FreeSpace,DriveType from Win32_LogicalDisk
    var %x = $com(%com2,ExecQuery,3,bstr*,%q,dispatch* %com3)

    ; IMPORTANT: iterate results (THIS WAS MISSING)
    while ($comval(%com3,%i,DeviceID)) {

      var %drive = $v1
      var %size = $comval(%com3,%i,Size)
      var %free = $comval(%com3,%i,FreeSpace)
      var %type = $comval(%com3,%i,DriveType)

      if (%size > 0) {

        var %icon = $iif(%type == 4,🌐,💽)

        var %free_gb = $calc(%free / 1073741824)
        var %total_gb = $calc(%size / 1073741824)

        var %out %out %icon %drive $+( ,$round(%free_gb,1),/,$round(%total_gb,1),GB |)
      }

      inc %i
    }

    .comclose %com
    .comclose %com2
    .comclose %com3

    return $iif(%out,$left(%out,$calc($len(%out) - 2)),💾 No disks found)
  }

  ; NETWORK (NOW INCLUDES WAN)
  if ($1 == net) {
    return $mooi(netname) - $mooi(netspeed) | 🖧 LAN $mooi(lanip) | 🌍 WAN $mooi(wanip)
  }

  ; UPTIME
  if ($1 == up) return $duration($mooi(up))
}

;-------------------------------------------------------------
; SYSTEM INFO (WMI)
;-------------------------------------------------------------

alias mooi {

  if ($1 == ostitle) return $wmiget(Win32_OperatingSystem).Caption
  if ($1 == up) return $uptime(system,3)

  if ($1 == cpuname) return $wmiget(Win32_Processor).Name
  if ($1 == gfxproc) return $wmiget(Win32_VideoController).VideoProcessor

  if ($1 == rammax) return $round($calc($wmiget(Win32_OperatingSystem).TotalVisibleMemorySize / 1024),1)
  if ($1 == ramuse) return $round($calc($wmiget(Win32_OperatingSystem).FreePhysicalMemory / 1024),1)

  if ($1 == netname) return $wmiget(Win32_NetworkAdapter where NetEnabled=True).Name
  if ($1 == netspeed) return $calc($wmiget(Win32_NetworkAdapter where NetEnabled=True).Speed / 1000000) $+ Mb/s

  if ($1 == lanip) return $ip
  if ($1 == wanip) return $remove($urlget(https://api.ipify.org),$crlf)
}

;-------------------------------------------------------------
; RAM BAR
;-------------------------------------------------------------

alias moorambar {
  var %size = 10
  var %used = $round($calc($1 / 100 * %size),0)
  var %unused = $calc(%size - %used)
  return $+([,$str(|,%used),$str(-,%unused),])
}

;-------------------------------------------------------------
; WMI HELPER (SAFE)
;-------------------------------------------------------------

alias wmiget {
  var %com = moo.wmi1, %com2 = moo.wmi2, %com3 = moo.wmi3

  if ($com(%com)) .comclose %com
  if ($com(%com2)) .comclose %com2
  if ($com(%com3)) .comclose %com3

  .comopen %com WbemScripting.SWbemLocator
  var %x = $com(%com,ConnectServer,3,dispatch* %com2)
  var %x = $com(%com2,ExecQuery,3,bstr*,select $prop from $1,dispatch* %com3)

  var %result = $comval(%com3,1,$prop)

  .comclose %com | .comclose %com2 | .comclose %com3
  return %result
}

alias com.reset {
  if ($com(moo.h1)) .comclose moo.h1
  if ($com(moo.h2)) .comclose moo.h2
  if ($com(moo.h3)) .comclose moo.h3
}
