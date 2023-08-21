#!/bin/ksh

# chk_clu.sh: get some info on the yb-cluster, and loop that...
#
# todo: node-list should be variable...
# todo: masterlist still hardcoded, risky?
# todo: separate for YB-Masters and YB-Servers ? 
#

# do quick check first, minimal info, mininalsleep, just quick....
# I notably want to verify the IP addy of each node.
for node in node1 node2 node3 node4 node5 node6 node7
do

  echo doing node $node  
  echo $node:
  docker exec $node  ps -ef  | grep database_host | cut -d= -f2  
  docker exec -it $node yugabyted status ; sleep 0 ; echo .

done

# now loop more slowly over nodes, if too much load: sleep longer
while true 
do

  for node in node1 node2 node3 node4 node5 node6 node7
  do

    echo $node:
    docker exec $node ps -ef  | grep database_host | cut -d= -f2  
    docker exec -it $node yugabyted status | grep atus; sleep 5 ; echo .

    echo .
    echo $node get_universe_config:
    docker exec -it $node yb-admin \
      --master_addresses node1:7100,node2:7100,node3:7100 \
      get_universe_config  | jq | grep clusterUu

    echo .
    echo $node list_all_masters:
    docker exec -it $node yb-admin \
      --master_addresses node1:7100,node2:7100,node3:7100 \
      list_all_masters

    echo .
    echo $node list_all_t-servers:
    docker exec -it $node yb-admin \
      --master_addresses node1:7100,node2:7100,node3:7100 \
      list_all_tablet_servers

    echo ----- $node done, next.. 

    sleep 2

  done

  echo ----- loop over nodes done, next.. 
  sleep 9

done 

# ------------------- end chk_clu.sh --------------


# more, nomally, code never gets this far..

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

