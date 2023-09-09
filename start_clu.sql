#!/bin/ksh

#
# start_clu.sh: start a list of nodes
#
# todo: clear sockets to start postgres? (minor?)
#

set -v -x 

# nodelist="node1 node2 node3 node4 node5 node6"
nodelist="node2 node3 node4 node5 node6 node7 node8 "


for node in $nodelist
do

  docker start $node
  sleep 1

  # remove socket (if exists...)
  cat <<EOF | docker exec -i $node sh
    rm -rf /tmp/.yb.*
    ls -ltra /tmp

EOF

docker stop $node
sleep 3
docker start $node

done

