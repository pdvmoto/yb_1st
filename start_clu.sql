#!/bin/ksh

#
# start_clu.sh: start a list of nodes
#
# todo: clear sockets to start postgres? (minor?)
#

# set -v -x 

# nodelist="node1 node2 node3 node4 node5 node6"
# nodelist="node2 node3 node4 node5 node6 node7 node8 nodeX nodeY "
nodelist="node2 node3 node4 node5 node6 node7 node8 "


for node in $nodelist
do

  echo .
  echo starting $node

  docker start $node
  sleep 2

  # remove socket (if exists...)
  cat <<EOF | docker exec -i $node sh
    rm -rf /tmp/.yb.*
    ls -ltra /tmp

EOF

  # docker stop $node
  # sleep 2
  # docker start $node
  # sleep 2
  docker exec $node yugabyted start

  echo .
  echo `date` $0 : [stop and] started YB containers
  echo `date` $0 : now adding st_sadc and ashloop 
  echo `date` $0   push start-process to background to avoid wait-loops ...

  echo .

  docker exec -it $node startsadc.sh & 
  docker exec -it $node st_ashloop.sh &

done

