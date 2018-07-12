#!/bin/bash
###############################################################################
# This script may help us correlate system events occurred in dmesg with other
# ES events by converting system time to human readable *local* time in dmesg.
#
# _Disclaimer, the human readable output in dmesg may be off by few seconds due
# to rounding errors from top_
#
# **Usage:**
# ```
# cd diagnostics-%datetime%
# convert_dmesg_time.sh
# ```
#
# **Prerequisite:**
# It reads files collected from [ES support diagnostics tool]
# (https://github.com/elastic/support-diagnostics). 
# The following files must be present for it to work.
# - dmesg.txt (with system timestamp)
# - top.txt
# - manifest.json
#
#
# **Example input:**
# ```
# [2518647.427425] Out of memory: Kill process 20757 (java) score 78 or sacrifice child
# [2518647.433502] Killed process 20757 (java) total-vm:7901288kB, anon-rss:1275032kB, file-rss:11068kB
# ```

# **Example output:**
# ```
# [2018-07-06 22:14:23] Out of memory: Kill process 20757 (java) score 78 or sacrifice child
# [2018-07-06 22:14:23] Killed process 20757 (java) total-vm:7901288kB, anon-rss:1275032kB, file-rss:11068kB
# ```
#
# _Currently supports Mac (Darwin) and Linux, no windows support yet._
#
# Todo:
# Windows
#
# Leaf Lin 2018-Jul-12
###############################################################################

function epoch_to_human_readable(){ 
  if [[ $os = *"Darwin"* ]]; then
    date -r $1 "+%Y-%m-%d %T"  #Mac
  elif [[ $os = *"Linux"* ]]; then
    date -d @$1 "+%Y-%m-%d %T"  #Linux
  else
    echo " Unknown OS, please submit a git issue"
  fi
}

function human_readable_to_epoch(){ 
  if [[ $os = *"Darwin"* ]]; then
    date -j -f "%Y-%m-%d %H:%M:%S" "$1 $2" +"%s" #Mac
  elif [[ $os = *"Linux"* ]]; then
    date -d "$1 $2" +%s #Linux
  else
    echo " Unknown OS, please submit a git issue"
  fi
}

function get_next_day(){ 
  if [[ $os = *"Darwin"* ]]; then
    date -v "+1d" -j -f "%Y-%m-%d" $1 +"%Y-%m-%d" #Mac
  elif [[ $os = *"Linux"* ]]; then
    date -d "$1 +1 day" +"%Y-%m-%d" #Linux
  else
    echo " Unknown OS, please submit a git issue"
  fi
}

#0. Check necessary file exists.
if [[ ! -f manifest.json || ! -f top.txt || ! -f dmesg.txt ]]; then
  echo " One of the files does not exist: manifest.json, top.txt, or dmesg.txt"
  exit 1
fi

#1. Check user's OS (this is the user runs this conversion tool, not user who collects the diag.)
os=$(uname)


#2. Grab collect date from manifest.json
# Here we ignore timezone as the collection timezone should be the same as boot timezone.
collect=$( grep "collectionDate" manifest.json | awk '{print$3}' | sed 's/"//g' )

if [[ $collect =~ ([0-9]{4}-[0-9]{2}-[0-9]{2})T([0-9]{2}:[0-9]{2}:[0-9]{2}).[0-9]{3}([-+][0-9]{2})([0-9]{2}) ]]; then
  collect_date=${BASH_REMATCH[1]}  #local
  collect_time=${BASH_REMATCH[2]}  #local

fi


#3. Grab top time and uptime from top.txt

line=$( grep "^top -" top.txt )
if [[ $line =~ ^top[[:space:]]-[[:space:]]([0-9]{2}:[0-9]{2}:[0-9]{2})[[:space:]]up(.*),[[:space:]]+[0-9]+[[:space:]]+user.* ]]; then
  top_time=${BASH_REMATCH[1]} #local
  day="0"
  hr="0"
  min="0"
  sec="0"
  uptime=(${BASH_REMATCH[2]})
  if [[ ${uptime[1]} = *"day"* && ${uptime[2]} = *":"* ]]; then #X day(s), hh:mm
    day=${uptime[0]}
    hr=$( echo ${uptime[2]} | awk -F ':' '{print$1}')
    min=$( echo ${uptime[2]} | awk -F ':' '{print$2}')
  elif [[ ${uptime[1]} = *"day"* && ${uptime[3]} = *"min"* ]]; then # X day(s), Y min
    day=${uptime[0]}
    min=${uptime[2]}
  elif [[ ${uptime[0]} = *":"* ]]; then # hh:mm
    hr=$( echo ${uptime[0]} | awk -F ':' '{print$1}')
    min=$( echo ${uptime[0]} | awk -F ':' '{print$2}')
  elif [[ ${uptime[1]} = *"min"* ]]; then # X min(s)
    min=${uptime[0]}
  elif [[ ${uptime[1]} = *"sec"* ]]; then # X sec(s)
    sec=${uptime[0]}
  fi
  let up_seconds=$day*86400+$hr*3600+$min*60+$sec

  #collec_time should be close to top_time
  top_epoch=$( human_readable_to_epoch $collect_date $top_time)
  collect_epoch=$( human_readable_to_epoch $collect_date $collect_time)
  ((diff=$collect_epoch-$top_epoch))
  if [ $diff -le 36000 ]; then #assumes less than 10 hours between collect and top is ok
    top_date=$collect_date
  else
    top_date=$(get_next_day $collect_date)
  fi
  collect_epoch=$(human_readable_to_epoch $top_date $top_time)
fi

#4. Get boot time. 
# But since collect time in top does not have seconds, this is a fair assumption.

let boot_time_epoch=($collect_epoch - $up_seconds)
boot_time_hr=$(epoch_to_human_readable $boot_time_epoch)
collect_hr=$(epoch_to_human_readable $collect_epoch)
echo " Boot at: $boot_time_hr"
echo " Collect: $collect_hr"

#5. Get dmesg time, and convert to human readable time
if [[ -z $boot_time_epoch || -z $collect_epoch ]] ; then # One of the time is unset or empty
  echo " Time conversion is broken"
else
  while IFS='' read -r line; do
    if [[ $line =~ ^\[\ *([0-9]+)\.[0-9]+\]\ (.*) ]]; then
      stamp=$(($boot_time_epoch+${BASH_REMATCH[1]}))
      stamp_hr=$(epoch_to_human_readable $stamp)
      echo "[$stamp_hr] ${BASH_REMATCH[2]}"
    else
      echo "$line"
    fi

  done < "dmesg.txt" > dmesg_human_readable_time.txt

  echo " dmesg_human_readable_time.txt is now ready!"

fi
