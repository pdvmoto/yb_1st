#!/bin/bash

# run_ash1.sh: loop over all nodes to collect ash (And generate rrs?)
#
# typical usage: either permanent loop, or after a benchmark, to secure ash-data 
#

#  verify first, show command

ASHFILE=do_ash_client.sql

ASH_ON_NODE=/usr/local/bin/do_ash.sh

SNAPNODE=node2
SNAPFILE=/usr/local/bin/do_snap.sh

PAUSE_SEC=120

countdown() {
  echo .
  echo -- countdown $1 sec -- 
  echo .
  local seconds=$1
  for ((i=seconds; i>=0; i--)); do
    echo -ne "\r $i Counting down ... "
    sleep 1
  done
  echo -e "\nTime's up!"
}

# countdown $1


echo .
echo `date` $0 : \[  $* \] ... 
echo .

nodenrs="2 3 4 5 6 7 8 9" 

nodenames="node2 node3 node4 node5 node6 node7 node8 node9 nodeA nodeB nodeC"

while true
do

  SECONDS=0

  # use container names (nodenames) and docker exec to avoid problems with port-nrs
  for hname in $nodenames
  do

    echo .
    echo ---- `date '+%Y-%m-%d %H:%M:%S'` $0 : ---- Doing $hname  -------
    echo .

    docker exec  $hname $ASH_ON_NODE
    # any other command for the node: here..

    echo .
    echo ---- `date '+%Y-%m-%d %H:%M:%S'` $0 : ---- Done $hname  -------
    echo .

    # just a brief pause..
    sleep 1 

  done

  # 1 node to do OS-level snapshot..
  docker exec $SNAPNODE  $SNAPFILE

  echo .
  echo ---- `date '+%Y-%m-%d %H:%M:%S'` $0 : ---- Looped in $SECONDS sec. Will re-start after $PAUSE_SEC sec sleep.  -------
  echo .

  countdown ${PAUSE_SEC}  
  #   sleep ${PAUSE_SEC}

done

echo .
ehco --- $0 should never get here... ---
ehco .
