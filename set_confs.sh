#!/bin/ksh

# set_confs.sh: loop over all nodes and set conf files from subdir
#
# todo: HARDcoded nodenames TWICE: make a list.
#
#

#  verify first, show command

echo .
echo pushing out yugabytd.conf to all nodes, subdir : ./conf/
echo .

mkdir ./conf

# do it once, quick...
for node in node2 node3 node4 node5 node6 node7 node8
do

  echo doing node $node  
  docker exec $node mkdir /root/var/conf
  docker cp ./conf/yugabyted.$node $node:/root/var/conf/yugabyted.conf 

done


echo .
echo copies done..
ls -l ./conf/*

echo .

