#!/bin/ksh

#
# start_ashloop.sh: start collection of ash
#
# note: can add other loops or utilitis later, e.g. collect wait_events?
#
#

# set -v -x 

# nodelist="node1 node2 node3 node4 node5 node6"
nodelist="node2 node3 node4 node5 node6 node7 node8 "


for node in $nodelist
do

  echo .
  echo starting yb-ashloop on $node

  # using EOF to make ampersand work ?
  cat <<EOF | docker exec -i $node sh 
    nohup do_ashloop.sh & 
EOF

  exitcode=$? 
  echo .
  echo started on node $node code $exitcode
  echo . 

  # check..
  docker exec -it $node ps -ef | grep do_ashloop
  echo .

  sleep 2

done

