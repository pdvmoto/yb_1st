#!/bin/ksh
# set -v -x
#
# mk_p.sh: generate a node for prometheus.
#
# tricks: no start command required, 
#         but need to replace /etc/prometheus/prometheus.yml 
#         copy config files into /tmp ? 
#         first desingate node4 to scrape, most used node
#
# todo:
#  - experiment with multi-nodes
#
# Q: is there a way to measure "effort", possibly "chattyness" ?
#
# notes
# old images ? : 
#
# choose an image
  P_IMAGE=prom/prometheus:v2.37.9

# get some file to log stmnts, start simple
LOGFILE=mk_prom_node.log

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
#

echo creating nodeP

crenode=` \
echo docker run -d --network yb_net       \
  --hostname nodep --name nodep           \
  -p9090:9090                             \
  $P_IMAGE
 
echo $hname ... creating container:
echo $crenode

echo $crenode >> $LOGFILE

# do it..
$crenode

echo nodeP created..
echo .
echo . 
echo Have Fun.
echo .
