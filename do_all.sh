#!/bin/ksh

# do_all_clu.sh: loop over all nodes with a command...
#
# todo: HARDcoded nodenames TWICE: make a list.
#
# typical usage: measure disk-usage, or check tablets..
# ./do_all.sh du -sh --inodes /root/var/data/yb-data/
# ./do_all.sh yb-admin  -master_addresses node1:7100 list_tablets ysql.yugabyte t_1st 0 
#

#  verify first, show command

echo .
echo do_all_clu: \[  $* \] ... 
echo .

# do it once, quick...
for node in node2 node3 node4 node5 node6 node7 node8
do

  echo doing node $node  
  docker exec -it $node $*

done


echo .
echo do_all_clu.sh: Cntr-C or ...continue doing it slower forever...
echo . 

sleep 10

# now loop slowly over nodes
while true 
do

  echo .
  echo do_all: \[  $* \] ... 
  echo .

  for node in  node2 node3 node4 node5 node6 node7 node8
  do

    # echo doing node $node  
    docker exec -it $node $*

    sleep 2 

  done

  echo ----- do_all_clu.sh: loop over nodes done, next.. 
  sleep 10

done 

# ----------------- end do_all_clu.sh -------------

echo .
echo notes: code should never get this far.. but keep as notes
echo .

sleep 10

while true 
do

  echo node1:
  docker exec node1  ps -ef  | grep database_host | cut -d= -f2  
  docker exec -it node1 yugabyted status | grep atus; sleep 3 ; echo .

  echo node2:
  docker exec node2  ps -ef  | grep database_host | cut -d= -f2  
  docker exec -it node2 yugabyted status | grep atus; sleep 3 ; echo .

  echo node3:
  docker exec node3  ps -ef  | grep database_host | cut -d= -f2  
  docker exec -it node3 yugabyted status | grep atus; sleep 3 ; echo .

  echo node4:
  docker exec node4  ps -ef  | grep database_host | cut -d= -f2  
  docker exec -it node4 yugabyted status | grep atus; sleep 6 ; echo .

  echo node5:
  docker exec node5  ps -ef  | grep database_host | cut -d= -f2  
  docker exec -it node4 yugabyted status | grep atus; sleep 6 ; echo .

  echo node6:
  docker exec node6  ps -ef  | grep database_host | cut -d= -f2  
  docker exec -it node4 yugabyted status | grep atus; sleep 6 ; echo .

done 

