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
  podman stop $node
  sleep 1
  podman rm $node
  echo $node is gone
done


# keep net, re-use IPs, easier 
# podman network rm yb_net

sleep 1

podman network list

podman ps -a

echo .
echo rmoved, now verify: 
echo  - podman ps -a
echo  - podman network list 
echo . 
echo Have Fun.
echo .
echo .
