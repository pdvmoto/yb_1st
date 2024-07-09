#!/bin/sh

#
# start_ashloop.sh: start collection of ash
#
# Why doesnt this work from script.. seems to work fine when done manually ?
# 
# note: can add other loops or utilitis later, e.g. collect wait_events?
#
#

set -v -x 

# nodelist="node1 node2 node3 node4 node5 node6"
nodelist="node2 node3 node4 node5 "


for node in $nodelist
do

  echo .
  echo starting yb-ashloop on $node

  docker exec $node bash <<EOF
    nohup /usr/local/bin/do_ashloop.sh >> /tmp/do_ashloop.out &  
    echo nohup started on $node exitcode $?

EOF

  exitcode=$? 
  echo .
  echo $0 : started on node $node code $exitcode
  echo . 

  # check..
  docker exec $node ps -ef | grep do_ashloop
  echo .

  sleep 2

done

