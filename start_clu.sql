#!/bin/ksh

#
# start_clu.sh: start a list of nodes
#
# todo: clear sockets to start postgres? (minor?)
#

# set -v -x 

# nodelist="node1 node2 node3 node4 node5 node6"
# nodelist="node2 node3 node4 node5 node6 node7 node8 nodeX nodeY "
nodelist="node2 node3 node4 node5 node6 node7 "


for node in $nodelist
do

  echo .
  echo starting $node

  docker start $node
  sleep 1

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
  echo `date` $0 : [stop and] started YB containe on $node
  echo `date` $0 : now try adding st_sadc and ashloop 
  echo `date` $0 : push start-process to background to avoid wait-loops ...

  echo .
  echo `date` $0 : skip sadc and ashloop for efficiency.

  # docker exec -it $node startsadc.sh  
  # docker exec -it $node st_ashloop.sh 
  sleep 2
  docker exec -it $node do_stuff.sh

done

echo .
echo `date` $0 : done, 
echo `date` $0 : check all background processes, sar, ashloop...
echo .


