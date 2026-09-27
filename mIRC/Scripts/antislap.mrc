on *:ACTION:*:*:{
  ; Check if the action contains the word "slaps" and your nickname
  if (($regex($1-, /slaps.* $+ $me \b/i)) && ($nick != $me)) {
    ; Prevent spamming by using a 3-second cooldown variable
    if (%antislap) { return }
    set -u3 %antislap 1

    ; Retaliate with an action back to the channel
    describe $chan dodges $nick $+ 's lame attempt and slaps them right back with a massive trout!
  }
}
