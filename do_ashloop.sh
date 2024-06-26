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
#   - configur nr seconds as parameter, dflt 300
#   - test sleep-pg vs sleep-linux, consume a pg-process, but give sleep-wait ? 
#   - configure for credentials ? 
#

while true 
do

  date "+%Y-%m-%dT%H:%M:%S do_ashloop.sh: running on host $HOSTNAME ..."

  ysqlsh -h $HOSTNAME -X <<EOF
    select ybx_get_ash () ;
    select get_tablets () ;

EOF
  
  # echo on host: $HOSTNAME
  echo .
  date "+ %Y-%m-%dT%H:%M:%S do_ashloop.sh: sleeping on $HOSTNAME ..."
  echo .

  sleep 300

done

echo do_ashloop.sh: should never get here...

