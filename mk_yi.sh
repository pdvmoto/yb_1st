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
# docker pull yugabytedb/yugabyte:2.19.3.0-b140
# docker pull yugabytedb/yugabyte:2.20.1.0-b97      
#
# notes on placement:
#   3 zones, with 2 nodes each ?
#   start with putting nodes in zones..

# depreciate: how many nodes...(node2 is special!)
# nodelist="node6 node7 node8"

# choose an image
# YB_IMAGE=yugabytedb/yugabyte:latest
# YB_IMAGE=yugabytedb/yugabyte:2.19.0.0-b190        \
# YB_IMAGE=yugabytedb/yugabyte:2.20.1.0-b97
# YB_IMAGE=yugabytedb/yugabyte:2.20.1.3-b3
# YB_IMAGE=yugabytedb/yugabyte:2.21.0.0-b545
  YB_IMAGE=yugabytedb/yugabyte:2.21.1.0-b271

# get some file to log stmnts, start simple
LOGFILE=mk_nodes.log

echo `date` $0 : creating cluster... >> $LOGFILE

# docker network rm yb_net
# sleep 2
docker network create --subnet=172.20.0.0/16 --ip-range=172.20.0.0/24  yb_net
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

# nodenrs="2 3 4 5 6 7 8"
  nodenrs=" 6 7 8 "

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

  echo creating node ${hname}

  crenode=` \
  echo docker run -d --network yb_net        \
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
  sleep 2
  
  echo $hname : adding tools 
  echo .

  echo $hname : adding profile to already present bashrc...
  docker cp yb_profile.sh $hname:/tmp/
  docker exec -it $hname sh -c "cat /tmp/yb_profile.sh >> /root/.bashrc "

  echo $hname : adding psqlrc
  docker cp ~/.psqlrc $hname:/tmp
  docker exec -it $hname sh -c "cp /tmp/.psqlrc /root/.psqlrc"

  echo $hname : adding ybflags.conf
  docker cp ybflags.conf $hname:/home/yugabyte/

  echo $hname : adding psg ...
  docker cp `which psg`     $hname:/usr/local/bin/psg
  docker exec -it $hname chmod 755 /usr/local/bin/psg

  echo $hname : adding ff ...
  docker cp `which ff`      $hname:/usr/local/bin/ff
  docker exec -it $hname chmod 755 /usr/local/bin/ff

  echo $hname : adding do_ashloop.sh and st_ startscript ...
  docker cp do_ashloop.sh             $hname:/usr/local/bin/do_ashloop.sh
  docker exec -it $hname   chmod 755         /usr/local/bin/do_ashloop.sh
  docker cp st_ashloop.sh             $hname:/usr/local/bin/st_ashloop.sh
  docker exec -it $hname   chmod 755         /usr/local/bin/st_ashloop.sh

  echo $hname : add startsadc.sh or similar to help collect sar
  docker cp startsadc.sh    $hname:/usr/local/bin/startsadc.sh
  docker exec -it $hname chmod 755 /usr/local/bin/startsadc.sh
  # detach, or do it later, bcse takes 30sec: 
  # docker exec -it $hname startsadc.sh &
  
  # more tooling... make sure the files are in working dir

  echo $hname : adding yugatool and enabling ysql_bench...
  docker cp yugatool.gz $hname:/home/yugabyte/bin
  cat <<EOF | docker exec -i $hname sh
    gunzip /home/yugabyte/bin/yugatool.gz
    chmod 755 /home/yugabyte/bin/yugatool
    ln -s /home/yugabyte/bin/yugatool /usr/local/bin/yugatool
    ln -s /home/yugabyte/postgres/bin/ysql_bench /usr/local/bin/ysql_bench
EOF

  # echo $hname : adding jq .... Why first 
  # skip jq, libs and yum need too much space ?
  echo $hname : installing jq and chrony ...
  # docker cp jq $hname:/usr/bin/jq
  docker exec $hname yum install jq -y
  docker exec $hname yum install chrony -y

  echo .
  echo $hname : tools installed.
  echo .

  sleep 2

done


echo .
echo nodes created, next is starting yb 
echo .
echo .
echo pause 5 sec to Cntr-C .. or continue...
echo . 

sleep 5


echo .
echo node2 is the first node, need to Create the DB, other will just Join
echo .

# docker exec node2 yugabyted start --advertise_address=node2 --background=true --ui=true
  docker exec node2 yugabyted start \
    --advertise_address=node2       \
    --tserver_flags=flagfile=/home/yugabyte/ybflags.conf \
     --master_flags=flagfile=/home/yugabyte/ybflags.conf 

echo .
echo database created on node2: 5 sec to Cntr-C .. or .. loop Start over all nodes.
echo .
echo note: we tolerate an error for node2 to allow uniform command for all nodes.
echo .

sleep 5

for nodenr in $nodenrs
do

  hname=node${nodenr} 

  startcmd=`echo docker exec ${hname} yugabyted start --advertise_address=$hname --join=node2 \
    --tserver_flags=flagfile=/home/yugabyte/ybflags.conf \
     --master_flags=flagfile=/home/yugabyte/ybflags.conf `

  echo command will be : ${startcmd}

  echo $hname ... creating yugabyte instance:
  echo $startcmd

  echo $startcmd >> $LOGFILE
  ${startcmd}

  echo .
  sleep 3

done


# ---- add a generic platform, worker-node.. ----

# use nodeX, to have a neutral node in the network, 

$hname=nodeX

crenode=` \
  echo docker run -d --network yb_net        \
    --hostname $hname --name $hname          \
    $YB_IMAGE                                \
    tail -f /dev/null `

  echo $hname ... creating container:
  echo $crenode
    
  echo $crenode >> $LOGFILE                  
    
  # do it..
  $crenode

  echo .
  sleep 2

  echo $hname : adding tools 
  echo .

  echo $hname : adding profile to already present bashrc...
  docker cp yb_profile.sh $hname:/tmp/
  docker exec -it $hname sh -c "cat /tmp/yb_profile.sh >> /root/.bashrc "

  echo $hname : adding psqlrc
  docker cp ~/.psqlrc $hname:/tmp
  docker exec -it $hname sh -c "cp /tmp/.psqlrc /root/.psqlrc"

  echo $hname : adding ybflags.conf
  docker cp ybflags.conf $hname:/home/yugabyte/

  echo $hname : adding psg ...
  docker cp `which psg`     $hname:/usr/local/bin/psg
  docker exec -it $hname chmod 755 /usr/local/bin/psg

  echo $hname : adding ff ...
  docker cp `which ff`      $hname:/usr/local/bin/ff
  docker exec -it $hname chmod 755 /usr/local/bin/ff

  echo $hname : adding do_ashloop.sh and st_ startscript ...
  docker cp do_ashloop.sh             $hname:/usr/local/bin/do_ashloop.sh
  docker exec -it $hname   chmod 755         /usr/local/bin/do_ashloop.sh
  docker cp st_ashloop.sh             $hname:/usr/local/bin/st_ashloop.sh
  docker exec -it $hname   chmod 755         /usr/local/bin/st_ashloop.sh

  echo $hname : add startsadc.sh or similar to help collect sar
  docker cp startsadc.sh    $hname:/usr/local/bin/startsadc.sh
  docker exec -it $hname chmod 755 /usr/local/bin/startsadc.sh
  # detach, or do it later, bcse takes 30sec: 
  # docker exec -it $hname startsadc.sh &
  
  # more tooling... make sure the files are in working dir

  echo $hname : adding yugatool and enabling ysql_bench...
  docker cp yugatool.gz $hname:/home/yugabyte/bin
  cat <<EOF | docker exec -i $hname sh
    gunzip /home/yugabyte/bin/yugatool.gz
    chmod 755 /home/yugabyte/bin/yugatool
    ln -s /home/yugabyte/bin/yugatool /usr/local/bin/yugatool
    ln -s /home/yugabyte/postgres/bin/ysql_bench /usr/local/bin/ysql_bench

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
# docker exec -it node2 yugabyted status 
# docker exec -it node3 yugabyted status 
# docker exec -it node4 yugabyted status 
# docker exec -it node5 yugabyted status 
# docker exec -it node6 yugabyted status 
# docker exec -it node7 yugabyted status 
# docker exec -it node8 yugabyted status 

echo .
echo Scroll back and check if it all workd...
echo .
echo Also verify: 
echo  - connecting cli    : ysqlsh -h localhost -p 5433 -U yugabyte
echo  - inspect dashboard : localhost:15433 
echo  - inspect node3:    : localhost:7003  and 9003, etc...
echo . 
echo . If so desired : 
echo .    - run yb_init.sql to load often-used functions.
echo .    - run mk_ybash.sql prepare ash-logging
echo .    - run mk_ashvws.sql to prepare live-ash viewing via gv$
echo .    - activate do_ahsloop.sh on every node,  why no nohup from docker exec? 
echo .    - activate startsadc.sh to use sar
echo .    - run demo_fill.sql to load demo-table t, use checks/monitor.
echo .    - run mk_longt.sql to fill large-ish table
echo . 
echo Have Fun.
echo .
echo .
