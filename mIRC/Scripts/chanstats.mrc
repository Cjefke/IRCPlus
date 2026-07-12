; Basic Stats v1.4 - by entropy 2020
; Syntax: !cstats (total stats)
; Syntax: !tstats (today's stats)
; Syntax: !top10 <stat>
; Syntax: !ttop10 <stat> (today's stats)
; %nostats nicks to not use stats here

menu channel,status,menubar,query {
  -
  Stats Channels v1.4
  .Turn $iif($group(#stats).status == on,Off,On) {
    $iif($group(#stats).status == on,.disable,.enable) #stats
    echo -tag $chr(9679) [Stats] is now: $replace($group(#stats).status,o,O)
  }
  .-
  .Set Channels { var %a = $input(Stats Channels? (sep. by comma),5,Stats Channels:,%stats_chans) | if (%a) { %stats_chans = %a | echo -tag $chr(9679) [Stats] Channels now: %a } }
  -
}

on *:unload:{ echo -tag $chr(9679) [Stats] unloaded! | unset %stats_chans }
on *:load:{ echo -tag $chr(9679) [Stats] v1.4 loaded - by entropy 2020 }

#stats on
on *:start:{
  clearoldstats
  .timerupdatestats -o 0 86400 clearoldstats
}
alias -l getstats {
  ;$getstats(<file>,<nick>)
  if ($read($1,wn,* $2)) { return $gettok($v1,1,32) }
  else { return 0 }
}
alias -l getstat { return $iif($read($1,w,* $2),$+($chr(40),$ord($readn),$chr(41))) }
alias -l getfile { var %a = $remove($mklogfn(#),.log,$+(.,$network),#) | if (!%a) { %a = # } | return $qt($+($scriptdir,Stats\,$network,.,%a,.,$1,.txt)) }
alias -l getfile2 { var %a = $remove($mklogfn($1),.log,$+(.,$network),$1) | if (!%a) { %a = $1 } | return $qt($+($scriptdir,Stats\,$network,.,%a,.,$2,.txt)) }

alias -l getfile3 { var %a = $remove($mklogfn(#),.log,$+(.,$network),#) | var %r = $replace($adate,/,-) | if (!%a) { %a = # } | return $qt($+($scriptdir,Today\,$network,.,%r,.,%a,.,$1,.txt)) }
alias -l getfile4 { var %a = $remove($mklogfn($1),.log,$+(.,$network),$1) | var %r = $replace($adate,/,-) | if (!%a) { %a = $1 } | return $qt($+($scriptdir,Today\,$network,.,%r,.,%a,.,$2,.txt)) }

alias delstats {
  ;/delstats <nick>
  if (!$1) { return }
  var %a = 1, %b, %s = words chars lines colors modes joins parts quits nicks actions kicks kicked topics smiles swears
  while ($chan(%a)) {
    %b = $v1
    var %x = 1, %y
    while ($gettok(%s,%x,32)) {
      %y = $v1
      if ($read($getfile2(%b,%y),w,* $1)) { write -dl $+ $readn $getfile2(%b,%y) }
      if ($read($getfile4(%b,%y),w,* $1)) { write -dl $+ $readn $getfile4(%b,%y) }
      inc %x
    }
    inc %a
  }
}

alias clearoldstats {
  var %a = 1, %b, %c, %total = 0
  while ($findfile($qt($scriptdirToday),*.txt, %a)) {
    %c = $v1
    %b = $gettok(%c,2,46)
    if ($replace($adate,/,-) != %b) { inc %total | .remove $qt(%c) }
    inc %a
  }
  ;echo -tag Done. %total file(s) deleted!
}

alias -l dostats {
  ;/dostats <file> <N> <nick>
  if ($istok(%nostats,$3,32)) { return }

  if (!$isdir($qt($scriptdirStats))) { mkdir $qt($scriptdirStats) }
  if (!$isdir($qt($scriptdirToday))) { mkdir $qt($scriptdirToday) }

  if ($read($1,wnt,* $3)) { write -dl $+ $readn $1 }
  var %a = 1, %b, %added = no
  while ($read($1,nt,%a)) {
    %b = $v1
    if ($2 >= $gettok(%b,1,32)) { write -il $+ %a $1- | %added = yes | break }
    inc %a
  }
  if (%added == no) { write $1- }
}

on *:input:%stats_chans:{ if (/* !iswm $1 && $server) { morestats $me $1- } }
on *:text:*:%stats_chans:{ morestats $nick $1- }

alias -l morestats {

  tokenize 32 $1 $strip($2-)

  var %a = $getfile(words) | dostats %a $calc($getstats(%a,$1) + $numtok($2-,32)) $1
  var %a = $getfile(chars) | dostats %a $calc($getstats(%a,$1) + $len($remove($2-,$chr(32)))) $1
  var %a = $getfile(lines) | dostats %a $calc($getstats(%a,$1) + 1) $1

  var %a = $getfile3(words) | dostats %a $calc($getstats(%a,$1) + $numtok($2-,32)) $1
  var %a = $getfile3(chars) | dostats %a $calc($getstats(%a,$1) + $len($remove($2-,$chr(32)))) $1
  var %a = $getfile3(lines) | dostats %a $calc($getstats(%a,$1) + 1) $1

  ; Smilies
  var %b = 1, %c = :S :X :D :o :) :P :b :] :[ :| D: :)) :(( :< :> :-) :-( :O) :O( =D =) =)) D= =] =[, %d, %e = 0
  while ($gettok(%c,%b,32)) {
    %d = $v1
    if ($istok($2-,%d,32)) { inc %e $count($2-,%d) }
    inc %b
  } 
  if (%e > 0) { 
    var %a = $getfile(smiles) | dostats %a $calc($getstats(%a,$1) + %e) $1
    var %a = $getfile3(smiles) | dostats %a $calc($getstats(%a,$1) + %e) $1
  }

  ; Swears
  var %e = 0
  if (shit isin $2-) { inc %e $count($2-,$v1) }
  if (asshole isin $2-) { inc %e $count($2-,$v1) }
  if (bitch isin $2-) { inc %e $count($2-,$v1) }
  if (cunt isin $2-) { inc %e $count($2-,$v1) }
  if (fag isin $2-) { inc %e $count($2-,$v1) }
  if (whore isin $2-) { inc %e $count($2-,$v1) }
  if (nigger isin $2-) { inc %e $count($2-,$v1) }
  if (twat isin $2-) { inc %e $count($2-,$v1) }
  if (cock isin $2-) { inc %e $count($2-,$v1) }
  if (pussy isin $2-) { inc %e $count($2-,$v1) }  
  if (stfu isin $2-) { inc %e $count($2-,$v1) }
  if (wtf isin $2-) { inc %e $count($2-,$v1) }
  if (gtfo isin $2-) { inc %e $count($2-,$v1) }
  if (fuck isin $2-) { inc %e $count($2-,$v1) }
  if (lmfao isin $2-) { inc %e $count($2-,$v1) }

  if (%e > 0) { 
    var %a = $getfile(swears) | dostats %a $calc($getstats(%a,$1) + %e) $1
    var %a = $getfile3(swears) | dostats %a $calc($getstats(%a,$1) + %e) $1
  }








  var %a = $getfile(colors)
  var %g = $calc($getstats(%a,$1) + $count($2-,$chr(3)))
  if (%g > 0) { dostats %a %g $1 }

  var %a = $getfile3(colors)
  var %g = $calc($getstats(%a,$1) + $count($2-,$chr(3)))
  if (%g > 0) { dostats %a %g $1 }

  if (?cstats iswm $2 && $left($2,1) isin @!.) {
    if ($3) { var %n = $3 }
    else { var %n = $1 }
    var %a = $getfile(words) | var %x = $bytes($getstats(%a,%n),b)
    var %a2 = $getfile(chars) | var %x2 = $bytes($getstats(%a2,%n),b)
    var %a3 = $getfile(lines) | var %x3 = $bytes($getstats(%a3,%n),b)
    var %a4 = $getfile(colors) | var %x4 = $bytes($getstats(%a4,%n),b)
    var %a5 = $getfile(modes) | var %x5 = $bytes($getstats(%a5,%n),b)
    var %a6 = $getfile(joins) | var %x6 = $bytes($getstats(%a6,%n),b)
    var %a7 = $getfile(parts) | var %x7 = $bytes($getstats(%a7,%n),b)
    var %a8 = $getfile(quits) | var %x8 = $bytes($getstats(%a8,%n),b)
    var %a9 = $getfile(nicks) | var %x9 = $bytes($getstats(%a9,%n),b)
    var %a10 = $getfile(actions) | var %x10 = $bytes($getstats(%a10,%n),b)
    var %a11 = $getfile(kicks) | var %x11 = $bytes($getstats(%a11,%n),b)
    var %a12 = $getfile(kicked) | var %x12 = $bytes($getstats(%a12,%n),b)
    var %a13 = $getfile(topics) | var %x13 = $bytes($getstats(%a13,%n),b)
    var %a14 = $getfile(smiles) | var %x14 = $bytes($getstats(%a14,%n),b)
    var %a15 = $getfile(swears) | var %x15 = $bytes($getstats(%a15,%n),b)

    var %n2 = [Stats] $chr(9679) Nick: %n $chr(9679) Words: %x $getstat(%a,%n) $chr(9679) Chars: %x2 $getstat(%a2,%n) $chr(9679) Lines: %x3 $getstat(%a3,%n) $chr(9679) Colors: %x4 $getstat(%a4,%n) $chr(9679) Modes: %x5 $getstat(%a5,%n) $chr(9679) Joins: %x6 $getstat(%a6,%n) $chr(9679) Parts: %x7 $getstat(%a7,%n) $chr(9679) Quits: %x8 $getstat(%a8,%n) $chr(9679) Nicks: %x9 $getstat(%a9,%n) $chr(9679) Actions: %x10 $getstat(%a10,%n) $chr(9679) Kicks: %x11 $getstat(%a11,%n) $chr(9679) Kicked: %x12 $getstat(%a12,%n) $chr(9679) Topics: %x13 $getstat(%a13,%n) $chr(9679) Smiles: %x14 $getstat(%a14,%n) $chr(9679) Swears: %x15 $getstat(%a15,%n)
    var %n3 = $remove(%n2,$chr(9679) Words: 0,$chr(9679) Chars: 0,$chr(9679) Lines: 0,$chr(9679) Colors: 0,$chr(9679) Modes: 0,$chr(9679) Joins: 0,$chr(9679) Parts: 0,$chr(9679) Quits: 0,$chr(9679) Nicks: 0,$chr(9679) Actions: 0,$chr(9679) Kicks: 0,$chr(9679) Kicked: 0,$chr(9679) Topics: 0,$chr(9679) Smiles: 0,$chr(9679) Swears: 0)

    if ($numtok(%n3,32) == 4) { msg # No stats available! }
    else { msg # %n3 }
  }

  elseif (?tstats iswm $2 && $left($2,1) isin @!.) {
    if ($3) { var %n = $3 }
    else { var %n = $1 }
    var %a = $getfile3(words) | var %x = $bytes($getstats(%a,%n),b)
    var %a2 = $getfile3(chars) | var %x2 = $bytes($getstats(%a2,%n),b)
    var %a3 = $getfile3(lines) | var %x3 = $bytes($getstats(%a3,%n),b)
    var %a4 = $getfile3(colors) | var %x4 = $bytes($getstats(%a4,%n),b)
    var %a5 = $getfile3(modes) | var %x5 = $bytes($getstats(%a5,%n),b)
    var %a6 = $getfile3(joins) | var %x6 = $bytes($getstats(%a6,%n),b)
    var %a7 = $getfile3(parts) | var %x7 = $bytes($getstats(%a7,%n),b)
    var %a8 = $getfile3(quits) | var %x8 = $bytes($getstats(%a8,%n),b)
    var %a9 = $getfile3(nicks) | var %x9 = $bytes($getstats(%a9,%n),b)
    var %a10 = $getfile3(actions) | var %x10 = $bytes($getstats(%a10,%n),b)
    var %a11 = $getfile3(kicks) | var %x11 = $bytes($getstats(%a11,%n),b)
    var %a12 = $getfile3(kicked) | var %x12 = $bytes($getstats(%a12,%n),b)
    var %a13 = $getfile3(topics) | var %x13 = $bytes($getstats(%a13,%n),b)
    var %a14 = $getfile3(smiles) | var %x14 = $bytes($getstats(%a14,%n),b)
    var %a15 = $getfile3(swears) | var %x15 = $bytes($getstats(%a15,%n),b)

    var %n2 = [Today's Stats] $chr(9679) Nick: %n $chr(9679) Words: %x $getstat(%a,%n) $chr(9679) Chars: %x2 $getstat(%a2,%n) $chr(9679) Lines: %x3 $getstat(%a3,%n) $chr(9679) Colors: %x4 $getstat(%a4,%n) $chr(9679) Modes: %x5 $getstat(%a5,%n) $chr(9679) Joins: %x6 $getstat(%a6,%n) $chr(9679) Parts: %x7 $getstat(%a7,%n) $chr(9679) Quits: %x8 $getstat(%a8,%n) $chr(9679) Nicks: %x9 $getstat(%a9,%n) $chr(9679) Actions: %x10 $getstat(%a10,%n) $chr(9679) Kicks: %x11 $getstat(%a11,%n) $chr(9679) Kicked: %x12 $getstat(%a12,%n) $chr(9679) Topics: %x13 $getstat(%a13,%n) $chr(9679) Smiles: %x14 $getstat(%a14,%n) $chr(9679) Swears: %x15 $getstat(%a15,%n)
    var %n3 = $remove(%n2,$chr(9679) Words: 0,$chr(9679) Chars: 0,$chr(9679) Lines: 0,$chr(9679) Colors: 0,$chr(9679) Modes: 0,$chr(9679) Joins: 0,$chr(9679) Parts: 0,$chr(9679) Quits: 0,$chr(9679) Nicks: 0,$chr(9679) Actions: 0,$chr(9679) Kicks: 0,$chr(9679) Kicked: 0,$chr(9679) Topics: 0,$chr(9679) Smiles: 0,$chr(9679) Swears: 0)

    if ($numtok(%n3,32) == 5) { msg # No stats available! }
    else { msg # %n3 }
  }

  elseif (?ttop10 iswm $2 && $left($2,1) isin @!.) {

    if ($3 == $null) { tokenize 32 $1-2 words on }

    if ($istok(words chars lines colors modes joins parts quits nicks actions kicks kicked topics smiles swears,$3,32)) {
      var %a = 1, %b, %t, %r
      while (%a <= 10) {
        if ($read($getfile3($3),%a)) { %t = %t $chr(9679) $+($chr(40),$ord(%a),$chr(41)) $gettok($v1,2,32) $+([,$bytes($gettok($v1,1,32),b),]) }
        inc %a
      }
      if (%t) { msg # [Today's Top10 $3 $+ ] %t }
      else { msg # No ttop10 stats available! }
    }
    else { msg # No such stat! Stats: <words|chars|lines|colors|modes|joins|parts|quits|nicks|actions|kicks|kicked|topics|smiles|swears> }    
  }
  elseif (?top10 iswm $2 && $left($2,1) isin !@.) {
    if (!$3) { msg # No stat specified! Syntax: !top10 <stat> }
    else {
      if ($istok(words chars lines colors modes joins parts quits nicks actions kicks kicked topics smiles swears,$3,32)) {
        var %a = 1, %b, %t, %r
        while (%a <= 10) {
          if ($read($getfile($3),%a)) { %t = %t $chr(9679) $+($chr(40),$ord(%a),$chr(41)) $gettok($v1,2,32) $+([,$bytes($gettok($v1,1,32),b),]) }
          inc %a
        }
        if (%t) { msg # [Top10 $3 $+ ] %t }
        else { msg # No top10 stats available! }
      }
      else { msg # No such stat! Stats: <words|chars|lines|colors|modes|joins|parts|quits|nicks|actions|kicks|kicked|topics|smiles|swears> }
    }
  }
}
on *:action:*:%stats_chans:{

  tokenize 32 $strip($1-)

  var %a = $getfile(actions) | dostats %a $calc($getstats(%a,$nick) + 1) $nick
  var %a = $getfile(words) | dostats %a $calc($getstats(%a,$nick) + $0) $nick
  var %a = $getfile(chars) | dostats %a $calc($getstats(%a,$nick) + $len($remove($1-,$chr(32)))) $nick
  var %a = $getfile(lines) | dostats %a $calc($getstats(%a,$nick) + 1) $nick

  var %a = $getfile3(actions) | dostats %a $calc($getstats(%a,$nick) + 1) $nick
  var %a = $getfile3(words) | dostats %a $calc($getstats(%a,$nick) + $0) $nick
  var %a = $getfile3(chars) | dostats %a $calc($getstats(%a,$nick) + $len($remove($1-,$chr(32)))) $nick
  var %a = $getfile3(lines) | dostats %a $calc($getstats(%a,$nick) + 1) $nick


  ; Smilies
  var %b = 1, %c = :S :X :D :) :P :b :] :[ :| D: :)) :(( :< :> :-) :-( :O) :O(, %d, %e = 0
  while ($gettok(%c,%b,32)) {
    %d = $v1
    if ($istok($1-,%d,32)) { inc %e $count($1-,%d) }
    inc %b
  } 
  if (%e > 0) { 
    var %a = $getfile(smiles) | dostats %a $calc($getstats(%a,$nick) + %e) $nick
    var %a = $getfile3(smiles) | dostats %a $calc($getstats(%a,$nick) + %e) $nick
  }

  ; Swears
  var %e = 0
  if (shit isin $1-) { inc %e $count($1-,$v1) }
  if (asshole isin $1-) { inc %e $count($1-,$v1) }
  if (bitch isin $1-) { inc %e $count($1-,$v1) }
  if (cunt isin $1-) { inc %e $count($1-,$v1) }
  if (fag isin $1-) { inc %e $count($1-,$v1) }
  if (whore isin $1-) { inc %e $count($1-,$v1) }
  if (nigger isin $1-) { inc %e $count($1-,$v1) }
  if (twat isin $1-) { inc %e $count($1-,$v1) }
  if (cock isin $1-) { inc %e $count($1-,$v1) }
  if (pussy isin $1-) { inc %e $count($1-,$v1) }  
  if (stfu isin $1-) { inc %e $count($1-,$v1) }
  if (wtf isin $1-) { inc %e $count($1-,$v1) }
  if (gtfo isin $1-) { inc %e $count($1-,$v1) }
  if (lmfao isin $1-) { inc %e $count($1-,$v1) }
  if (fuck isin $1-) { inc %e $count($1-,$v1) }

  if (%e > 0) { 
    var %a = $getfile(swears) | dostats %a $calc($getstats(%a,$nick) + %e) $nick
    var %a = $getfile3(swears) | dostats %a $calc($getstats(%a,$nick) + %e) $nick
  }
}
on *:join:%stats_chans:{ 
  var %a = $getfile(joins) | dostats %a $calc($getstats(%a,$nick) + 1) $nick
  var %a = $getfile3(joins) | dostats %a $calc($getstats(%a,$nick) + 1) $nick
}
on *:part:%stats_chans:{ 
  var %a = $getfile(parts) | dostats %a $calc($getstats(%a,$nick) + 1) $nick
  var %a = $getfile3(parts) | dostats %a $calc($getstats(%a,$nick) + 1) $nick
}
on *:quit:{ 
  var %a = 1, %b, %z, %c
  while ($comchan($nick,%a)) {
    %b = $v1

    if ($istok(%stats_chans,%b,44)) {
      %c = $getfile2(%b,quits)
      dostats %c $calc($getstats(%c,$nick) + 1) $nick

      %c = $getfile4(%b,quits)
      dostats %c $calc($getstats(%c,$nick) + 1) $nick
    }
    inc %a
  }
}
on *:nick:{ 
  var %a = 1, %b, %z, %c
  while ($comchan($newnick,%a)) {
    %b = $v1

    if ($istok(%stats_chans,%b,44)) {
      %c = $getfile2(%b,nicks)
      dostats %c $calc($getstats(%c,$newnick) + 1) $newnick

      %c = $getfile4(%b,nicks)
      dostats %c $calc($getstats(%c,$newnick) + 1) $newnick
    }
    inc %a
  }
}
on *:kick:%stats_chans:{ 
  var %a = $getfile(kicks) | dostats %a $calc($getstats(%a,$nick) + 1) $nick
  var %a = $getfile(kicked) | dostats %a $calc($getstats(%a,$knick) + 1) $knick

  var %a = $getfile3(kicks) | dostats %a $calc($getstats(%a,$nick) + 1) $nick
  var %a = $getfile3(kicked) | dostats %a $calc($getstats(%a,$knick) + 1) $knick
}
on *:rawmode:%stats_chans:{ 
  var %a = $getfile(modes) | dostats %a $calc($getstats(%a,$nick) + $len($remove($1,+,-))) $nick
  var %a = $getfile3(modes) | dostats %a $calc($getstats(%a,$nick) + $len($remove($1,+,-))) $nick
}

on *:topic:%stats_chans:{ 
  var %a = $getfile(topics) | dostats %a $calc($getstats(%a,$nick) + 1) $nick
  var %a = $getfile3(topics) | dostats %a $calc($getstats(%a,$nick) + 1) $nick
}
#stats end
