#!/bin/ksh

#
# clean_socket.sh: remove sockets on a yb-containers, allow starting of componetnts
#
# $1 - node
# todo: HARDcoded paths...
#

set -v -x 

# nodelist="node1 node2 node3 node4 node5 node6"
nodelist="node2 node3 node4 node5 node6 node7 node8 "

node=$1

cat <<EOF | docker exec -i $node sh
    rm -rf /tmp/.yb.*
    ls -ltra /tmp

EOF

docker stop $node
sleep 3
docker start $node
