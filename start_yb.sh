#!/bin/ksh

#
# start_yb.sh: start yugabyted on list of nodes
#
#

set -v -x 

# nodelist="node1 node2 node3 node4 node5 node6"
nodelist="node2 node3 node4 node5 node6 node7 node8 nodeX nodeY "


for node in $nodelist
do

  echo .
  echo starting yb on $node

  # remove socket (if exists...)
  cat <<EOF | docker exec -i $node sh
    rm -rf /tmp/.yb.*
    ls -ltra /tmp

EOF

  docker exec $node yugabyted start
  exitcode=$? 
  echo .
  echo started on node $node code $exitcode
  echo .
  sleep 2

done

