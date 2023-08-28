#!/bin/ksh
#
# rm_yb_c.sh: remove nodes 1-6
#
# This time: same 6 nodes, but more ports exposed.
#
# Q: is there a way to measure "effort", possibly "chattyness" ?
#

for node in node8 node7 node6 node5 node4 node3 node2 
do
  docker stop $node
  sleep 2
  docker rm $node
  sleep 2
done


# keep net, re-use IPs, easier 
# docker network rm yb_net

sleep 2

docker network list

docker ps -a

echo .
echo rmoved, now verify: 
echo  - docker ps -a
echo  - docker network list 
echo . 
echo Have Fun.
echo .
echo .
