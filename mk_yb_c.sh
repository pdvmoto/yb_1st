#!/bin/ksh
#
# mk_yb_c.sh: generate a yb cluster in docker
#
# This time: same 6+ nodes, but more ports exposed.
# trick: start at node2, so last digit of ip = node-nr
#
# todo:
#  - enhance /root/.bashrc  : do_profile.sh
#  - copy yugatool and link to /usr/local/bin : do_profile.sh 
#  - set worker node, ip-.10?
#
# purpose: check effets of too many tablets??
# compare to co-location?
#
# Q: is there a way to measure "effort", possibly "chattyness" ?
#

docker network rm yb_net
sleep 2
docker network create --subnet=172.20.0.0/16 --ip-range=172.20.0.0/24  yb_net

# start 1st master, call it node2, network address: node2.yb_net
docker run -d --network yb_net  \
  --hostname node2 --name node2 \
  -p15432:15433 -p5432:5433     \
  -p7002:7000 -p9002:9000       \
  yugabytedb/yugabyte           \
  yugabyted start --background=false --ui=true

# found out the hard way that a small pause is beneficial
sleep 20

#now add nodes..
docker run -d --network yb_net  \
  --hostname node3 --name node3 \
  -p15433:15433 -p5433:5433     \
  -p7003:7000 -p9003:9000       \
  yugabytedb/yugabyte           \
  yugabyted start --background=false --join node2.yb_net

sleep 15

docker run -d --network yb_net  \
  --hostname node4 --name node4 \
  -p15434:15433 -p5434:5433     \
  -p7004:7000 -p9004:9000       \
  yugabytedb/yugabyte           \
  yugabyted start --background=false --join node2.yb_net

sleep 10

docker run -d --network yb_net  \
  --hostname node5 --name node5 \
  -p15435:15433 -p5435:5433     \
  -p7005:7000 -p9005:9000       \
  yugabytedb/yugabyte           \
  yugabyted start --background=false --join node2.yb_net

sleep 10

docker run -d --network yb_net  \
  --hostname node6 --name node6 \
  -p15436:15433 -p5436:5433     \
  -p7006:7000 -p9006:9000       \
  yugabytedb/yugabyte           \
  yugabyted start --background=false --join node2.yb_net

sleep 10

docker run -d --network yb_net  \
  --hostname node7 --name node7 \
  -p15437:15433 -p5437:5433     \
  -p7007:7000 -p9007:9000       \
  yugabytedb/yugabyte           \
  yugabyted start --background=false --join node2.yb_net

docker run -d --network yb_net  \
  --hostname node8 --name node8 \
  -p15438:15433 -p5438:5433     \
   -p7008:7000  -p9008:9000     \
  yugabytedb/yugabyte           \
  yugabyted start --background=false --join node2.yb_net

#  -p13007:13000 -p12007:12000   \


# ---- add a generic platform, worker-node.. ----

# use nodeX, to have a neutral node in the network, 
docker run -d --network yb_net  \
  --hostname nodeX --name nodeX \
  --ip 172.20.0.21              \
  yugabytedb/yugabyte           \
  yugabyted start --background=false --ui=true

# health checks:
docker exec -it node1 yugabyted status 
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
echo Have Fun.
echo .
echo .
