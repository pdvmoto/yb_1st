#!/bin/ksh
#
# mk_yi.sh: generate a yb cluster in docker, interactive nodes (servers).
#
# This time: same 6+ nodes, same ports exposed.
# trick: start with some other program to similate server-light containers, 
#        then start yugabyted "manually"
#
# todo:
#  - create loop over nodes 3-8, easier on script
#  - automatically enhance /root/.bashrc  : do_profile.sh
#  - automatically copy yugatool and link to /usr/local/bin : do_profile.sh 
#  - set worker nodes, ip-.10?
#  - use yugabyted.conf as controlling file, parameter-file.
#  - is it enough to just specify "masters", instead of join ? 
#  - note: background=true and ui=true are specified, but those values are default ?
#
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
# nodelist="node2 node3 node4"

# choose an image
# YB_IMAGE=yugabytedb/yugabyte:latest
# YB_IMAGE=yugabytedb/yugabyte:2.19.0.0-b190        \
# YB_IMAGE=yugabytedb/yugabyte:2.20.1.0-b97
YB_IMAGE=yugabytedb/yugabyte:2.20.1.3-b3


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

nodenrs="2 3 4 5 6 7 8"

# create nodes, platform, no db yet...
for nodenr in $nodenrs
do

  # define all relevant pieces (no spaces!)
  hname=node${nodenr} 
  pgport=543${nodenr}
  yb7port=700${nodenr}
  yb9port=900${nodenr}
  yb15port=1543${nodenr}

  echo creating node ${hname}

  crenode=` \
  echo docker run -d --network yb_net        \
    --hostname $hname --name $hname          \
    -p${pgport}:5433                         \
    -p${yb7port}:7000 -p${yb9port}:9000      \
    -p${yb15port}:15433                      \
    -v /Users/pdvbv/yb_data/$hname:/root/var \
    $YB_IMAGE                                \
    tail -f /dev/null `
 
  echo $crenode

  # do it..
  $crenode

  echo .

  sleep 3

done


echo .
echo nodes created: 5 sec to Cntr-C .. or .. continue doing it slower forever...
echo . 

sleep 5


echo .
echo node2 is the first node, need to Create the DB, other will just Join
echo .

docker exec node2 yugabyted start --advertise_address=node2 --background=true --ui=true

echo .
echo database created on node2: 5 sec to Cntr-C .. or .. loop Start over all nodes.
echo .
echo note: we tolerate an error for node2 to allow uniform command for all nodes.
echo .

sleep 5

for nodenr in $nodenrs
do

  hname=node${nodenr} 

  startcmd=`echo docker exec ${hname} yugabyted start --advertise_address=$hname --join=node2 `

  echo command will be : ${startcmd}

  ${startcmd}

  echo .
  sleep 5

done


# ---- add a generic platform, worker-node.. ----

# use nodeX, to have a neutral node in the network, 
docker run -d --network yb_net  \
  --hostname nodeX --name nodeX \
  --ip 172.20.0.21              \
  $YB_IMAGE                             \
  yugabyted start --background=false --ui=true

# use nodeY, to have a neutral node, 10 days idle, in the network, 
docker run -d --network yb_net  \
  --hostname nodeY --name nodeY \
  --ip 172.20.0.22              \
  $YB_IMAGE                     \
  sleep 999999 

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
echo .    - complete config of nodes 2-8 using  ./do_profile.sh, loops over nodes!
echo .    - run yb_init.sql to load often-used functions.
echo .    - run demo_fill.sql to load demo-table t, and use it for checks/monitor.
echo . 
echo Have Fun.
echo .
echo .
