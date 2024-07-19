#!/bin/bash

# do_ashloop.sh: collect ash and tablet data in loop of 5min (300sec)
#
# usage; copy to each node and start with nohup.
#   nohup ./do_ashloop.sh & 
# 
# verify running with : 
#    select host, min(sample_time) earliest_sample, max(sample_time) latest_sample from ybx_ash group by host order by 3 desc ;
#
# todo:
#   - configur nr seconds as parameter, 120sec seems ok for now, measure durations..
#   - use semaphore to stop running
#   - test sleep-pg vs sleep-linux, consume a pg-process, detect sleep-wait ? 
#   - configure for credentials ? 
#   - add detection of new event where not exist in ybx_ash_eventlist
#

# a bit quick, during benchmarkng, but set to 5 or 10min later
N_SECS=120
F_SEM=/tmp/ybx_ash_off.sem

while true 
do

  if [ -f ${F_SEM} ]; then

    date "+%Y-%m-%dT%H:%M:%S do_ashloop.sh on ${HOSTNAME} : no ash, ${F_SEM} found "

  else 

    date "+%Y-%m-%dT%H:%M:%S do_ashloop.sh on ${HOSTNAME} : running ..."
  
    ysqlsh -h $HOSTNAME -X <<EOF
      \timing
      select ybx_get_ash () ;
      select get_tablets () ;
      select ybx_get_waiteventlist() as added_events;

EOF

  fi
 
  echo .
  date "+%Y-%m-%dT%H:%M:%S do_ashloop.sh on ${HOSTNAME} : sleeping ${N_SECS} ..."
  echo .

  sleep $N_SECS

done

echo do_ashloop.sh: should never get here...

