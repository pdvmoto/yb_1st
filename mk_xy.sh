#!/bin/ksh
# set -v -x
#
# mk_xysh: create worker nodes X and Y in yb_net.
#
# nodeX and nodeY mainly used as platform to run jobs or tweak other nodes
#
# todo:
#  - put profile + tools out there, beware of $MASTERS.
#  - automatically enhance /root/.bashrc  : do_profile.sh
#  - automatically copy yugatool and link to /usr/local/bin : do_profile.sh 
#  - consider hard ip addresses to stay out of range ?   --ip 172.20.0.21              \

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
# choose an image
# YB_IMAGE=yugabytedb/yugabyte:latest
# YB_IMAGE=yugabytedb/yugabyte:2.19.0.0-b190        \
# YB_IMAGE=yugabytedb/yugabyte:2.20.1.0-b97
# YB_IMAGE=yugabytedb/yugabyte:2.20.1.3-b3
YB_IMAGE=yugabytedb/yugabyte:latest


# normally "keep" this net
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
#  - how to get to K8s ??
#

# nodenrs="2 3 4 5 6 7 8"
# nodenrs="2 3 4"

nodenames="nodeX nodeY" 

# use loop to also copy relevant tools to nodes
for hname in $nodenames
do

  echo creating node ${hname}

  crenode=` \
  echo docker run -d --network yb_net        \
    --hostname $hname --name $hname          \
    $YB_IMAGE                                \
    tail -f /dev/null `
 
  echo $hname ... creating container:
  echo $crenode

  # do it..
  $crenode

  echo .
  sleep 1
  
  echo $hname : adding profile ...
  docker cp yb_profile.sh $hname:/tmp/
  docker exec -it $hname sh -c "cat /tmp/yb_profile.sh >> /root/.bashrc "

  echo $hname : adding psqlrc
  docker cp ~/.psqlrc $hname:/tmp
  docker exec -it $hname sh -c "cp /tmp/.psqlrc /root/.psqlrc"

  echo $node : adding ybflags.conf \(not needed on workernodes?\)
  docker cp ybflags.conf $hname:/home/yugabyte/

  echo $node : adding psg....
  docker cp `which psg` $hname:/usr/local/bin/psg
  docker exec -it $hname chmod 755 /usr/local/bin/psg

  # more tooling... make sure the files are in working dir

  echo $hname : adding jq ....
  # skip jq, libs and yum need too much space ?
  # echo $hname : installing jq  ...
  # docker cp jq $hname:/usr/bin/jq
  docker exec $hname yum install jq -y

  echo $hname : adding yugatool ...
  docker cp yugatool.gz $hname:/home/yugabyte/bin
  cat <<EOF | docker exec -i $hname sh
    gunzip /home/yugabyte/bin/yugatool.gz
    chmod 755 /home/yugabyte/bin/yugatool
    ln -s /home/yugabyte/bin/yugatool /usr/local/bin/yugatool
EOF

  echo .
  echo $hname : tools installed.
  echo .

  sleep 2

done


echo .
echo worker nodes created
echo .
echo if more config files needed: stop  + do_profile.sh
echo .

# ---- add a generic platform, worker-node.. ----


# health checks:
docker exec -it nodeX hostname
docker exec -it nodeX psg
docker exec -it nodeX df -h

docker exec -it nodeY hostname
docker exec -it nodeY psg
docker exec -it nodeY df -h

echo .
echo Scroll back and check if it all workd...
echo .
echo Have Fun.
echo .
echo .
