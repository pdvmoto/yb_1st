#!/bin/bash

# run_ash1.sh: loop over all nodes to collect ash (And generate rrs?)
#
# typical usage: either permanent loop, or after a benchmark, to secure ash-data 
#

#  verify first, show command

ASHFILE=do_ash_client.sql

ASH_ON_NODE=/usr/local/bin/do_ash.sh

SNAP_NODE=node2
SNAPFILE=/usr/local/bin/do_snap.sh

PAUSE_SEC=300

countdown() {
  echo .
  echo -- countdown $1 sec -- 
  echo .
  local seconds=$1
  for ((i=seconds; i>=0; i--)); do
    echo -ne "\rCountdown: $i "
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

  # create nodes, platform, install tools, but no db yet...
  # for nodenr in $nodenrs
  for hname in $nodenames
  do

    # define all relevant pieces (no spaces!)
    # hname=node${nodenr}
    # pgport=543${nodenr}
    # yb7port=700${nodenr}
    # yb9port=900${nodenr}
    # yb12p000=1200${nodenr}
    # yb13p000=1300${nodenr}
    # yb13port=1343${nodenr}
    # yb15port=1543${nodenr}

    echo .
    echo ---- `date '+%Y-%m-%d %H:%M:%S'` $0 : ---- Doing $hname  -------
    echo .

    # psql -h localhost -p ${pgport} -U yugabyte -X -f $ASHFILE

    docker exec  $hname $ASH_ON_NODE
    # any other command for the node: here..

    echo .
    echo ---- `date '+%Y-%m-%d %H:%M:%S'` $0 : ---- Done $hname  -------
    echo .

    # just a brief pause..
    sleep 3 

  done

  # 1 node to do OS-level snapshot..
  docker exec node2 $SNAPFILE

  echo .
  echo ---- `date '+%Y-%m-%d %H:%M:%S'` $0 : ---- Looped in $SECONDS sec. Will re-start after $PAUSE_SEC sec sleep.  -------
  echo .

  countdown ${PAUSE_SEC}  
  #   sleep ${PAUSE_SEC}

done

echo .
ehco --- $0 should never get here... ---
ehco .
