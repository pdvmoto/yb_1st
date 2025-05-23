#!/bin/ksh
# set -v -x
#
# mk_yi.sh: generate a yb cluster in docker, interactive nodes (servers).
#
# This time: same 6+ nodes, same ports exposed.
# trick: start with some other program to similate server-light containers, 
#        then start yugabyted "manually"
#
# todo:
#  - use yugabyted.conf as controlling file, parameter-file. - included: test more
#  - is it enough to just specify "masters", instead of join ? 
#  - note: background=true and ui=true are specified, but those values are default ?
#  - setting replication_factor=5: not trivial.. what is the trick ? 
#
# done..
#  - create loop over nodes 3-8, easier on script: done..
#  - automatically enhance /root/.bashrc  : do_profile.sh : done..
#  - automatically copy yugatool and link to /usr/local/bin : do_profile.sh  done.
#  - set worker nodes, ip-.10? done.. can, but not using it 
#
# purpose: check effets of too many tablets??
# compare to co-location?
#
# Q: is there a way to measure "effort", possibly "chattyness" ?
#
# notes
# old image: 
#  this one worked.. yugabytedb/yugabyte:2.19.0.0-b190        \
# newer image check sites...
# podman pull yugabytedb/yugabyte:2.19.3.0-b140
# podman pull yugabytedb/yugabyte:2.20.1.0-b97      
#
# notes on placement:
#   3 zones, with 2 nodes each ?
#   start with putting nodes in zones..

# depreciate: how many nodes...(node2 is special!)
# nodelist="node6 node7 node8"

# choose an image
# YB_IMAGE=yugabytedb/yugabyte:latest
# YB_IMAGE=yugabytedb/yugabyte:2.19.0.0-b190        
# YB_IMAGE=yugabytedb/yugabyte:2.20.1.0-b97
# YB_IMAGE=yugabytedb/yugabyte:2.20.1.3-b3
# YB_IMAGE=yugabytedb/yugabyte:2.21.0.0-b545
# YB_IMAGE=yugabytedb/yugabyte:2.21.1.0-b271
# YB_IMAGE=yugabytedb/yugabyte:2024.1.1.0-b137
  YB_IMAGE=pachot/yb-pg15
# YB_IMAGE=abhinabsaha/yugabytedb:latest_with_pid

# 26 Aug, didnt have yb_ash view ?
# YB_IMAGE=yugabytedb/yugabyte:2.20.6.0-b66

# latest was broken on 21-aug-2024?
# YB_IMAGE=yugabytedb/yugabyte:latest

# get some file to log stmnts, start simple
LOGFILE=mk_nodes.log

echo `date` $0 : creating cluster... >> $LOGFILE

# podman network rm yb_net
  podman network create --subnet=172.20.0.0/16 --ip-range=172.20.0.0/24  yb_net
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

  nodenrs="2 3 4 5"
# nodenrs="6 "
# nodenrs="  "

echo `date` $0 : ---- creating cluster for nodes : $nodenrs -------
echo .

# create nodes, platform, install tools, but no db yet...
for nodenr in $nodenrs
do

  # define all relevant pieces (no spaces!)
  hname=node${nodenr} 
  pgport=543${nodenr}
  yb7port=700${nodenr}
  yb9port=900${nodenr}
  yb13port=1343${nodenr}
  yb15port=1543${nodenr}

  echo `date` $0 : ---- doing node $hname  -------
  echo .

  crenode=` \
  echo podman run -d --network yb_net        \
    --hostname $hname --name $hname          \
    -p${pgport}:5433                         \
    -p${yb7port}:7000 -p${yb9port}:9000      \
    -p${yb13port}:13433                      \
    -p${yb15port}:15433                      \
    $YB_IMAGE                                \
    tail -f /dev/null `
 
  # to map volume, add this line just above YB_IMAGE..
  #  -v /Users/pdvbv/yb_data/$hname:/root/var \

  echo $hname ... creating container:
  echo $crenode
  echo $crenode >> $LOGFILE

  # do it..
  $crenode

  echo .
  sleep 1
  
  echo $hname : adding tools 
  echo .

  echo $hname : adding profile to already present bashrc...
  podman cp yb_profile.sh $hname:/tmp/
  podman exec -it $hname sh -c "cat /tmp/yb_profile.sh >> /root/.bashrc "

  echo $hname : adding psqlrc
  podman cp ~/.psqlrc $hname:/tmp
  podman exec -it $hname sh -c "cp /tmp/.psqlrc /root/.psqlrc"

  echo $hname : adding ybflags.conf
  podman cp ybflags.conf $hname:/home/yugabyte/

  # note: repeating steps for several (7 ?) files.. need function?

  echo $hname : adding psg ...
  podman cp `which psg`     $hname:/usr/local/bin/psg
  podman exec -it $hname chmod 755 /usr/local/bin/psg

  echo $hname : adding ff ...
  podman cp `which ff`      $hname:/usr/local/bin/ff
  podman exec -it $hname chmod 755 /usr/local/bin/ff

  echo $hname : adding do_ashloop.sh, start_script and do_ash.sql

  podman cp do_ashloop.sh             $hname:/usr/local/bin/do_ashloop.sh
  podman exec -it $hname   chmod 755         /usr/local/bin/do_ashloop.sh
  podman cp st_ashloop.sh             $hname:/usr/local/bin/st_ashloop.sh
  podman exec -it $hname   chmod 755         /usr/local/bin/st_ashloop.sh
  podman cp do_ash.sql                $hname:/usr/local/bin/do_ash.sql
  podman exec -it $hname   chmod 755         /usr/local/bin/do_ash.sql

  echo $hname : add unames.sql, -.sh, do_snap.sh
  podman cp unames.sh                 $hname:/usr/local/bin/unames.sh
  podman exec -it $hname   chmod 755         /usr/local/bin/unames.sh
  podman cp unames.sql                $hname:/usr/local/bin/unames.sql
  podman exec -it $hname   chmod 755         /usr/local/bin/unames.sql
  podman cp do_snap.sh                $hname:/usr/local/bin/do_snap.sh
  podman exec -it $hname   chmod 755         /usr/local/bin/do_snap.sh

  echo $hname : add startsadc.sh or similar to help collect sar
  podman cp startsadc.sh    $hname:/usr/local/bin/startsadc.sh
  podman exec -it $hname chmod 755 /usr/local/bin/startsadc.sh
  # detach, or do it later, bcse takes 30sec: 
  # podman exec -it $hname startsadc.sh &
  
  echo $hname : add do_stuff.sh or similar to help start all
  podman cp do_stuff.sh     $hname:/usr/local/bin/do_stuff.sh
  podman exec -it $hname chmod 755 /usr/local/bin/do_stuff.sh

  echo $hname : add yb_boot.sh or similar to boot ybdb
  podman cp yb_boot.sh      $hname:/usr/local/bin/yb_boot.sh
  podman exec -it $hname chmod 755 /usr/local/bin/yb_boot.sh

  # more tooling... make sure the files are in working dir

  echo $hname : adding yugatool and enabling ysql_bench...
  podman cp yugatool.gz $hname:/home/yugabyte/bin
  cat <<EOF | podman exec -i $hname sh
    gunzip /home/yugabyte/bin/yugatool.gz
    chmod 755 /home/yugabyte/bin/yugatool
    ln -s /home/yugabyte/bin/yugatool /usr/local/bin/yugatool
    ln -s /home/yugabyte/postgres/bin/ysql_bench /usr/local/bin/ysql_bench
EOF

  # echo $hname : adding jq .... Why first 
  # skip jq, libs and yum need too much space ?
  echo $hname : installing jq and chrony ...
  # podman cp jq $hname:/usr/bin/jq
  podman exec $hname yum install jq -y
  podman exec $hname yum install chrony -y

  echo .
  echo $hname : tools installed.
  echo .

  sleep 1

done
# for all nodes: node-created

echo .
echo nodes created, next is starting yb 
echo .
echo pause 5 sec to Cntr-C .. or continue...
echo . 

sleep 5


echo .
echo node2 is the first node, need to Create the DB, other will just Join
echo .

# podman exec node2 yugabyted start --advertise_address=node2 --background=true --ui=true

  startcmd=`echo podman exec node2 yugabyted start \
    --advertise_address=node2       \
    --tserver_flags=flagfile=/home/yugabyte/ybflags.conf \
     --master_flags=flagfile=/home/yugabyte/ybflags.conf `


  echo $hname ... creating yugabyte instance:
  echo $startcmd >> $LOGFILE
  echo $startcmd

echo .
echo database created on node2: 3 sec to Cntr-C .. or .. loop Start over all nodes.
echo .
echo note: we tolerate an error for node2 to allow uniform command for all nodes.
echo .

sleep 6

echo verify node2..
podman exec node2 yugabyted status 
echo .
echo another 6 sec ...


sleep 6

for nodenr in $nodenrs
do

  hname=node${nodenr} 

  startcmd=`echo podman exec ${hname} yugabyted start --advertise_address=$hname --join=node2 \
    --tserver_flags=flagfile=/home/yugabyte/ybflags.conf \
     --master_flags=flagfile=/home/yugabyte/ybflags.conf `

  # echo command will be : ${startcmd}

  echo $hname ... creating yugabyte instance:
  echo $startcmd
  echo $startcmd >> $LOGFILE

  # do it...
  ${startcmd}

  echo .
  sleep 3

done

echo .
echo Nodes created, and yugabte started..
echo .

# ---- add a generic platform, worker-node.. ----

# use nodeX, to have a neutral node in the network, 

# attempt at mulitple start-commands, to start sadc and ashloop in background, 
# not working yet..
# podman run -d --network yb_net --hostname nodeX --name nodeX yugabytedb/yugabyte:2.21.1.0-b271  sh -c " echo ` exec /usr/local/bin/do_stuff.sh ` > /var/log/start.log  && tail -f /dev/null" 
 
hname=nodeX

crenode=` \
  echo podman run -d --network yb_net        \
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
  echo .

  echo $hname : adding profile to already present bashrc...
  podman cp yb_profile.sh $hname:/tmp/
  podman exec -it $hname sh -c "cat /tmp/yb_profile.sh >> /root/.bashrc "

  echo $hname : adding psqlrc
  podman cp ~/.psqlrc $hname:/tmp
  podman exec -it $hname sh -c "cp /tmp/.psqlrc /root/.psqlrc"

  echo $hname : adding ybflags.conf
  podman cp ybflags.conf $hname:/home/yugabyte/

  echo $hname : adding psg ...
  podman cp `which psg`     $hname:/usr/local/bin/psg
  podman exec -it $hname chmod 755 /usr/local/bin/psg

  echo $hname : adding ff ...
  podman cp `which ff`      $hname:/usr/local/bin/ff
  podman exec -it $hname chmod 755 /usr/local/bin/ff

  echo $hname : adding do_ashloop.sh and st_ startscript ...
  podman cp do_ashloop.sh             $hname:/usr/local/bin/do_ashloop.sh
  podman exec -it $hname   chmod 755         /usr/local/bin/do_ashloop.sh
  podman cp st_ashloop.sh             $hname:/usr/local/bin/st_ashloop.sh
  podman exec -it $hname   chmod 755         /usr/local/bin/st_ashloop.sh

  echo $hname : add startsadc.sh or similar to help collect sar
  podman cp startsadc.sh    $hname:/usr/local/bin/startsadc.sh
  podman exec -it $hname chmod 755 /usr/local/bin/startsadc.sh
  # detach, or do it later, bcse takes 30sec: 
  # podman exec -it $hname startsadc.sh &
  
  echo $hname : add do_stuff.sh or similar to help start all
  podman cp do_stuff.sh    $hname:/usr/local/bin/do_stuff.sh
  podman exec -it $hname chmod 755 /usr/local/bin/do_stuff.sh

  # more tooling... make sure the files are in working dir

  echo $hname : adding yugatool and enabling ysql_bench...
  podman cp yugatool.gz $hname:/home/yugabyte/bin
  cat <<EOF | podman exec -i $hname sh
    gunzip /home/yugabyte/bin/yugatool.gz
    chmod 755 /home/yugabyte/bin/yugatool
    ln -s /home/yugabyte/bin/yugatool /usr/local/bin/yugatool
    ln -s /home/yugabyte/postgres/bin/ysql_bench /usr/local/bin/ysql_bench

echo $0 : $hname created...

# podman run -d --network yb_net  \
#   --hostname nodeX --name nodeX \
#   --ip 172.20.0.21              \
#   $YB_IMAGE                             \
#   yugabyted start --background=false --ui=true

# use nodeY, to have a neutral node, 10 days idle, in the network, 
# podman run -d --network yb_net  \
#   --hostname nodeY --name nodeY \
#   --ip 172.20.0.22              \
#   $YB_IMAGE                     \
#   sleep 999999 

# health checks:
# podman exec -it node2 yugabyted status 
# podman exec -it node3 yugabyted status 
# podman exec -it node4 yugabyted status 
# podman exec -it node5 yugabyted status 
# podman exec -it node6 yugabyted status 
# podman exec -it node7 yugabyted status 
# podman exec -it node8 yugabyted status 

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
