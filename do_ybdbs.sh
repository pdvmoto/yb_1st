#!/bin/ksh

# do_ybdbs.sh : loop over all yb-dbs (ports! )  with an sql-file $1
#
# todo: 
#  - HARDcoded ports .
#  - use node+port rather than dflt-localhost
#  - use -U, -d
#
# typical usage: schedule a command for all nodes, e.g. ash-collection
# ./do_ybdbs.sh do_ash.sql 
#
#  verify first, show command

portlist="5432 5433 5434 5435"

echo .
echo do_ybdbs with script : \[  $* \] ... 
echo .

# do it once, quick...
for portnr in $portlist
do

  ysqlsh -p $portnr -X -f $1

  sleep 3 

done


echo .
echo $0 : done all portnrs using $1 


echo .
echo do_all_clu.sh: 10 sec to Cntr-C .. or .. continue doing it slower forever...
echo . 

sleep 10

# now loop slowly over nodes
while true 
do

  echo .
  echo do_ybdbs: \[  $* \] every 60 sec... 
  echo .

  # loop over the portnrs
  for portnr in $portlist
  do

    ysqlsh -p $portnr -X -f do_ash.sql

  done

  sleep 60

done 

# ----------------- end do_all_clu.sh -------------

exit 

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

