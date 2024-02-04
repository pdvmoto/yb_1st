#!/bin/ksh

# get_confs.sh: loop over all nodes and pick up config fileb
#
# todo: HARDcoded nodenames TWICE: make a list.
#
#

#  verify first, show command

echo .
echo picking up yugabytd.conf from all nodes, subdir : ./conf/
echo .

mkdir ./conf

# do it once, quick...
for node in node2 node3 node4 node5 node6 node7 node8
do

  echo doing node $node  
  docker cp $node:/root/var/conf/yugabyted.conf ./conf/yugabyted.$node

done


echo .
echo copies done..
ls -l ./conf/*

echo .

