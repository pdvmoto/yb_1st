#!/bin/sh

#
# set_zone.sh: rollout rack/zone name for given nodes
#
# usage: set_zone.sh node-list rack
#
#

set -v -x 

echo $#

if [ "$#" -ne 2 ]; then
  echo
  echo $0 needs two arguments: $0 nodelist zonename
  echo 
  echo where 
  echo   nodelist = ' "node1 nodei2"  (quoted, space-separated list) '
  echo   zonename = newzone          ' (one word, valid zone name) ' 
  echo
  exit 1
fi

# nodelist="node1 node2 node3 node4 node5 node6"
nodelist=$1
zonename=$2


for node in $nodelist
do

  echo $node : setting rack to $zonename 

  cat <<EOF | docker exec -i $node sh
    cat /root/var/conf/yugabyted.conf | sed s/rack1/$zonename/g > /tmp/yugabyte.conf
    cp /tmp/yugabyte.conf /root/var/conf/yugabyted.conf
EOF
  
  # restart to have conf take effect
 
  docker stop $node
  sleep 2
  docker start $node
  # dont forget : ln -s /home/yugabyte/bin/yugatool /usr/local/bin/yugatool 

  sleep 2

done

echo .
echo nodes done: $nodelist
echo .
