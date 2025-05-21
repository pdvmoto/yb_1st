#!/bin/ksh

YB_IMAGE=yugabytedb/yugabyte:latest
LOGFILE=upd_nodes.log

nodenr=7

# define all relevant pieces (no spaces!)
hname=node${nodenr}
pgport=543${nodenr}
yb7port=700${nodenr}
yb9port=900${nodenr}
yb12p000=1200${nodenr}
yb13p000=1300${nodenr}
yb13port=1343${nodenr}
yb15port=1543${nodenr}


crenode=` \
echo docker run -d --network yb_net        \
  --hostname $hname --name $hname          \
  -p${pgport}:5433                         \
  -p${yb7port}:7000 -p${yb9port}:9000      \
  -p${yb12p000}:12000                      \
  -p${yb13p000}:13000                      \
  -p${yb13port}:13433                      \
  -p${yb15port}:15433                      \
  -v /Users/pdvbv/yb_data/$hname:/root/var \
  -v /Users/pdvbv/yb_data/sa:/var/log/sa   \
  $YB_IMAGE                                \
  tail -f /dev/null `


echo $hname ... creating container:
echo $crenode
echo $crenode >> $LOGFILE

# do it..
$crenode

# depose files..
./mk_nodesw.sh  $hname

echo $hname ... created container, check

# only if start is needed..
# note that start will use yugabyted.conf, and will thus use flagfiles

docker exec -it $hname yugabyted start
sleep 1
docker exec -it $hname yugabyted stop --upgrade=true
sleep 1
docker exec -it $hname yugabyted start
sleep 1
docker exec -it $hname yugabyted status

# problem was fixed.
# echo inject parameter from commandpromt, needs $MASTERS


