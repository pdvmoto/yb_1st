#!/bin/bash

# do_sarloop.sh: collect sar data in loop using ITER and INTV
#
# usage; 
#   copy (to each node) and start with nohup.
#   todo: start using st_sarloop.sh or do_stuff.sh 
# 
# verify running with : 
#    tail on logfile
#    select * from ybx_sadc_log
#
# todo:
#   - configur loop and interval parameter, 120sec seems ok for now, measure durations..
#   - SQL in separate file(s), easier to adjust, loop.sh just does the looping..
#   - use semaphore to stop running
#   - test sleep-pg vs sleep-linux, consume a pg-process, detect sleep-wait ? 
#   - configure for credentials ? 
#

# a bit quick, during benchmarkng, but set to 5 or 10min later

SECONDS=0

N_ITER=30
N_INTV=10
F_SEM=/tmp/ybx_sadc_off.sem
SAR_OUT_FILE=/tmp/sarloop.out

while true 
do

  if [ -f ${F_SEM} ]; then

    date "+%Y-%m-%dT%H:%M:%S do_ashloop.sh on ${HOSTNAME} : sar-loop Not running, ${F_SEM} found "

  else 

    date "+%Y-%m-%dT%H:%M:%S $0 on ${HOSTNAME} : running ..."
  
    sar $N_INTV $N_SEC > /tmp/sarloop.out

    cat /tmp/do_sarloop.out | tail -n+4  | head -n -1  | sed 's/ \+/\|/g' > def.out

    ysqlsh -h $HOSTNAME -X <<EOF

      \i /usr/local/bin/do_ash.sql

EOF

  fi
 
  echo .
  echo $0 on $HOSTNAME spent $SECONDS
  echo .
  date "+%Y-%m-%dT%H:%M:%S do_ashloop.sh on ${HOSTNAME} : sleeping ..."
  echo .

  if [ -f /tmp/ash_sleep.sh ]; then
      sh /tmp/ash_sleep.sh
  else
    echo .
    echo $0 `date` going to sleep for dflt $N_SECS
    sleep $N_SECS
  fi

done

echo do_ashloop.sh: should never get here...

