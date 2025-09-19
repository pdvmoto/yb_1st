#!/bin/ksh
# set -v -x
#
# mk_ora23.sh: start container using an oracle image.. (based on yb scripts..)
#
# todo:
#  - stop + recreate DB from crdb1_21.sh scripts
#

# choose an image
ORA_IMAGE=gvenzl/oracle-free:23.9-full-faststart

# YB_IMAGE=yugabytedb/yugabyte:2.19.0.0-b190        
# YB_IMAGE=yugabytedb/yugabyte:2.20.1.0-b97
# YB_IMAGE=yugabytedb/yugabyte:2.20.1.3-b3
# YB_IMAGE=yugabytedb/yugabyte:2.21.0.0-b545
# YB_IMAGE=yugabytedb/yugabyte:2.21.1.0-b271
# YB_IMAGE=yugabytedb/yugabyte:2024.1.1.0-b137
# YB_IMAGE=pachot/yb-pg15:latest
# YB_IMAGE=abhinabsaha/yugabytedb:latest_with_pid
# YB_IMAGE=yugabytedb/yugabyte:2024.2.2.0-b70 


# get some file to log stmnts, start simple
LOGFILE=mk_ora23.log

echo `date` $0 : creating cluster... >> $LOGFILE

# docker network rm yb_net
#  docker network create --subnet=172.20.0.0/16 --ip-range=172.20.0.0/24  yb_net
echo .
echo network yb_net created, next loop over nodes
echo .
sleep 2

# 
# test: 
#  - ways to start
#  - masters ? 
#  - with or without volume-mapping
#  - how to get to K8s ??
#

nodenrs="239 "
# nodenrs="6 7 8 9  "
# nodenrs="  "

echo `date` $0 : ---- creating cluster for nodes : $nodenrs -------
echo .

# create nodes, platform, install tools, but no db yet...
for nodenr in $nodenrs
do

  # define all relevant pieces (no spaces!)
  hname=o${nodenr}_dev
  oraport=1521

  echo .
  echo `date` $0 : ---- doing node $hname  -------
  echo .

  crenode=` \
  echo docker run -d        \
    --hostname $hname --name $hname          \
    -p1521:1521                              \
    $ORA_IMAGE                                \
    tail -f /dev/null `
 
  # to map volume, add this line just above YB_IMAGE..
  #  -v /Users/pdvbv/yb_data/$hname:/root/var \
  #  -v /Users/pdvbv/yb_data/sa:/var/log/sa   \

  echo $hname ... creating container:
  echo $crenode
  echo $crenode >> $LOGFILE

  # do it..
  $crenode

  echo .
  sleep 1
  
  echo .
  echo `date` $0 : ---- doing tools for node $hname  -------
  echo .

  echo $hname : adding profile to already present bashrc...
  docker cp yb_profile.sh $hname:/tmp/
  docker exec -it $hname sh -c "cat /tmp/yb_profile.sh >> /root/.bashrc "

  echo $hname : adding psqlrc
  docker cp ~/.psqlrc $hname:/tmp
  docker exec -it $hname sh -c "cp /tmp/.psqlrc /root/.psqlrc"

  echo $hname : adding copy of local .exrc
  docker cp ~/.exrc $hname:/tmp/exrc.add
  docker exec -it  $hname bash -c 'cat /tmp/exrc.add >> ~/.exrc' 

  echo $hname : adding ybflags.conf
  docker cp ybflags.conf       $hname:/home/yugabyte/
  docker cp yb_mast_flags.conf $hname:/home/yugabyte/
  docker cp yb_tsrv_flags.conf $hname:/home/yugabyte/

  # note: repeating steps for several (7 ?) files.. need function?

  echo $hname : adding psg ...
  docker cp `which psg`     $hname:/usr/local/bin/psg
  docker exec -it $hname chmod 755 /usr/local/bin/psg

  echo $hname : adding ff ...
  docker cp `which ff`      $hname:/usr/local/bin/ff
  docker exec -it $hname chmod 755 /usr/local/bin/ff

  echo $hname : adding do_ashloop.sh, start_script and do_ash.sql

  docker cp do_ashloop.sh             $hname:/usr/local/bin/do_ashloop.sh
  docker exec -it $hname   chmod 755         /usr/local/bin/do_ashloop.sh
  docker cp st_ashloop.sh             $hname:/usr/local/bin/st_ashloop.sh
  docker exec -it $hname   chmod 755         /usr/local/bin/st_ashloop.sh

  docker cp do_ash.sh                 $hname:/usr/local/bin/do_ash.sh
  docker exec -it $hname   chmod 755         /usr/local/bin/do_ash.sh
  docker cp do_ash.sql                $hname:/usr/local/bin/do_ash.sql
  docker exec -it $hname   chmod 755         /usr/local/bin/do_ash.sql

  docker cp ash_sleep.sh              $hname:/tmp/ash_sleep.sh
  docker exec -it $hname   chmod 755         /tmp/ash_sleep.sh

  echo $hname : add unames.sql, -.sh, do_snap.sh
  docker cp unames.sh                 $hname:/usr/local/bin/unames.sh
  docker exec -it $hname   chmod 755         /usr/local/bin/unames.sh
  docker cp unames.sql                $hname:/usr/local/bin/unames.sql
  docker exec -it $hname   chmod 755         /usr/local/bin/unames.sql

  docker cp do_snap.sh                $hname:/usr/local/bin/do_snap.sh
  docker exec -it $hname   chmod 755         /usr/local/bin/do_snap.sh

  echo $hname : add startsadc.sh or similar to help collect sar
  docker cp startsadc.sh    $hname:/usr/local/bin/startsadc.sh
  docker exec -it $hname chmod 755 /usr/local/bin/startsadc.sh
  # detach, or do it later, bcse takes 30sec: 
  # docker exec -it $hname startsadc.sh &
  
  echo $hname : add do_stuff.sh or similar to help start all
  docker cp do_stuff.sh     $hname:/usr/local/bin/do_stuff.sh
  docker exec -it $hname chmod 755 /usr/local/bin/do_stuff.sh

  echo $hname : add yb_boot.sh or similar to boot ybdb
  docker cp yb_boot.sh      $hname:/usr/local/bin/yb_boot.sh
  docker exec -it $hname chmod 755 /usr/local/bin/yb_boot.sh

  # more tooling... make sure the files are in working dir

  # echo $hname : adding jq .... Why first 
  # skip jq, libs and yum need too much space ?
  echo $hname : installing jq and chrony ...
  # docker cp jq $hname:/usr/bin/jq
  docker exec -u root $hname yum install jq -y
  docker exec -u root $hname yum install chrony -y

  echo .
  echo `date` $0 : ---- tools installed node $hname  -------
  echo .

  sleep 1

done
# for all nodes: node-created

echo .
echo nodes created, next is starting database,  
echo .
echo pause 5 sec to Cntr-C .. or continue...
echo . 

docker exec $hname /opt/oracle/container-entrypoint.sh 

echo .
echo node-creation done.. 
echo Verify ! 
echo .

exit  0 

sleep 5


echo .
echo node2 is the first node, need to Create the DB, other will just Join
echo .

# docker exec node2 yugabyted start --advertise_address=node2 --background=true --ui=true

  startcmd=`echo docker exec node2 yugabyted start \
    --advertise_address=node2       \
    --tserver_flags=flagfile=/home/yugabyte/yb_tsrv_flags.conf \
     --master_flags=flagfile=/home/yugabyte/yb_mast_flags.conf `

  echo $hname ... creating yugabyte instance:
  echo $startcmd >> $LOGFILE
  echo $startcmd

  # do it...
  ${startcmd}

echo .
echo database created on node2: 3 sec to Cntr-C .. or .. loop Start over all nodes.
echo .
echo note: we tolerate an error for node2 to allow uniform command for all nodes.
echo .

echo .
echo `date` $0 : ---- first instance done on node2 -------
echo .


sleep 5

echo verify node2..
docker exec node2 yugabyted status 
echo .
echo another 6 sec ...

sleep 6

for nodenr in $nodenrs
do

  hname=node${nodenr} 

  echo .
  echo `date` $0 : ---- starting YB on $hname -------
  echo .

  startcmd=`echo docker exec ${hname} yugabyted start --advertise_address=$hname --join=node2 \
    --tserver_flags=flagfile=/home/yugabyte/yb_tsrv_flags.conf \
     --master_flags=flagfile=/home/yugabyte/yb_mast_flags.conf `

  # echo command will be : ${startcmd}

  echo $hname ... creating yugabyte instance:
  echo $startcmd
  echo $startcmd >> $LOGFILE

  # do it...
  ${startcmd}

  echo .
  sleep 5

done

echo .
echo Nodes created, and yugabte started..
echo .

# ---- add a generic platform, worker-node.. ----

# use nodeX, to have a neutral node in the network, 

# attempt at mulitple start-commands, to start sadc and ashloop in background, 
# not working yet..
# docker run -d --network yb_net --hostname nodeX --name nodeX yugabytedb/yugabyte:2.21.1.0-b271  sh -c " echo ` exec /usr/local/bin/do_stuff.sh ` > /var/log/start.log  && tail -f /dev/null" 
 
hname=nodeX

crenode=` \
  echo docker run -d --network yb_net        \
    --hostname $hname --name $hname          \
    $YB_IMAGE  `

    #sh -c ' echo \` exec /usr/local/bin/do_stuff.sh \` > /var/log/start.log  && tail -f /dev/null\' `

  echo $hname ... creating container:
  echo $crenode
    
  echo $crenode >> $LOGFILE                  
    
  # do it..
  $crenode bash -xc '
    /usr/local/bin/do_stuff.sh
    tail -f /dev/null
  '

  echo .
  sleep 1

  echo $hname : adding tools 
  echo Consider creating a function to install tools on a node... 


echo $0 : $hname created...

# docker run -d --network yb_net  \
#   --hostname nodeX --name nodeX \
#   --ip 172.20.0.21              \
#   $YB_IMAGE                             \
#   yugabyted start --background=false --ui=true

# use nodeY, to have a neutral node, 10 days idle, in the network, 
# docker run -d --network yb_net  \
#   --hostname nodeY --name nodeY \
#   --ip 172.20.0.22              \
#   $YB_IMAGE                     \
#   sleep 999999 

# health checks:
 docker exec -it node2 yugabyted status 
 docker exec -it node3 yugabyted status 
 docker exec -it node4 yugabyted status 
 docker exec -it node5 yugabyted status 
 docker exec -it node6 yugabyted status 
 docker exec -it node7 yugabyted status 
 docker exec -it node8 yugabyted status 

echo .
echo Scroll back and check if it all workd...
echo .
echo Also verify: 
echo  - connecting cli    : ysqlsh -h localhost -p 5433 -U yugabyte
echo  - inspect dashboard : localhost:15433 
echo  - inspect node3:    : localhost:7003  and 9003, etc...
echo . 
echo . If so desired : 
echo .    - run yb_init.sql and demo_fill.sql to load often-used functions.
echo .    - run mk_ybash.sql prepare ash-logging
echo .    - run mk_ashvws.sql to prepare live-ash viewing via gv$
echo .    - use do_stuff.sh to run startsadc.sh and do_ashloop.sh
echo .    - activate st/do_ahsloop.sh on every node,  why no nohup from docker exec? 
echo .    - activate startsadc.sh to use sar
echo .    - run demo_fill.sql to load demo-table t, use checks/monitor.
echo .    - run mk_longt.sql to fill large-ish table
echo . 
echo Have Fun.
echo .
echo .
