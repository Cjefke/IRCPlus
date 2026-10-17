; ==========================================
; IRCPlus YouTube Info v1.2
; Https://IRCPlus.nl
; mIRC 7.84 - YouTube Data API v3
; ==========================================
; Configuration:
; /set %yt.api YOUR_API_KEY
; /set %yt.channels #IRCPlus,#Holland
; Detect YouTube links in channels

on *:TEXT:*:#:{
  if (%yt.api == $null) return
  if (!$istok(%yt.channels,$chan,44)) return
  var %text = $1-
  var %pattern = /(?:youtube\.com\/watch\?[^\s]*v=|youtu\.be\/|youtube\.com\/shorts\/)([A-Za-z0-9_-]{11})/i
  if ($regex(%text,%pattern)) {
    var %video = $regml(1)
    if ($hget(YTCache,%video)) return
    hadd -m YTCache %video 1
    .timer 1 300 hdel YTCache %video
    yt_lookup %video $chan
  }
}

; Request video information
alias yt_lookup {
  var %video = $1
  var %channel = $2
  var %file = $mircdir $+ yt_ $+ $ticks $+ .json
  ; IMPORTANT: statistics is now included
  var %url = https://www.googleapis.com/youtube/v3/videos?part=snippet,contentDetails,statistics $+ &id= $+ %video $+ &key= $+ %yt.api
  var %request = $urlget(%url,gf,%file,yt_callback)
  if (!%request) {
    echo -a [YouTube] Could not start API request.
    return
  }
  set %yt.file. $+ %request %file
  set %yt.channel. $+ %request %channel
  set %yt.video. $+ %request %video
}

; Process API response
alias yt_callback {
  var %request = $1
  var %file = $eval($+(%,yt.file.,%request),2)
  var %channel = $eval($+(%,yt.channel.,%request),2)
  var %video = $eval($+(%,yt.video.,%request),2)
  if (%file == $null) return
  if ($urlget(%request).state != ok) {
    echo -a [YouTube] API request failed.
    goto cleanup
  }
  if (!$isfile(%file)) goto cleanup
  ; Read complete JSON file
  var %json = $null
  var %i = 1
  while (%i <= $lines(%file)) {
    %json = %json $+ $read(%file,%i)
    inc %i
  }
  ; Check for API errors
  if ($regex(%json,/"error"\s*:/i)) {
    echo -a [YouTube] API error. Check your API key and quota.
    goto cleanup
  }
  if (!$regex(%json,/"items"\s*:\s*\[\s*\{/i)) {
    echo -a [YouTube] Video unavailable or no video data returned.
    goto cleanup
  }
  ; Extract title
  var %title = Unknown title
  if ($regex(%json,/"title"\s*:\s*"((?:\\.|[^"\\])*)"/i)) {
    %title = $regml(1)
  }
  ; Extract channel/uploader
  var %uploader = Unknown
  if ($regex(%json,/"channelTitle"\s*:\s*"((?:\\.|[^"\\])*)"/i)) {
    %uploader = $regml(1)
  }
  ; Extract ISO 8601 duration
  var %duration = Unknown
  var %hours = 0
  var %minutes = 0
  var %seconds = 0
  if ($regex(%json,/"duration"\s*:\s*"PT((?:\d+H)?(?:\d+M)?(?:\d+S)?)"/i)) {
    var %iso = $regml(1)
    if ($regex(%iso,/(\d+)H/i)) {
      %hours = $regml(1)
    }
    if ($regex(%iso,/(\d+)M/i)) {
      %minutes = $regml(1)
    }
    if ($regex(%iso,/(\d+)S/i)) {
      %seconds = $regml(1)
    }
    if (%hours > 0) {
      %duration = $+(%hours,:,$right($+(0,%minutes),2),:,$right($+(0,%seconds),2))
    }
    else {
      %duration = $+(%minutes,:,$right($+(0,%seconds),2))
    }
  }
  ; Extract view count
  var %views = Unknown
  if ($regex(%json,/"viewCount"\s*:\s*"(\d+)"/i)) {
    %views = $regml(1)
  }
  ; Extract publication date
  var %published = Unknown
  if ($regex(%json,/"publishedAt"\s*:\s*"(\d{4}-\d{2}-\d{2})/i)) {
    %published = $regml(1)
  }
  ; Keep output compact for IRC
  if ($len(%title) > 80) {
    %title = $left(%title,77) $+ ...
  }
  if ($len(%uploader) > 35) {
    %uploader = $left(%uploader,32) $+ ...
  }
  ; One-line announcement, no repeated URL
  if (%channel != $null) {
    var %line = [YouTube] $chr(9654) %title $chr(124) Length: %duration $chr(124) By: %uploader $chr(124) Views: %views $chr(124) Published: %published
    msg %channel %line
  }
  :cleanup
  if ($isfile(%file)) .remove %file
  unset %yt.file. $+ %request
  unset %yt.channel. $+ %request
  unset %yt.video. $+ %request
}
