#!/bin/ksh

#
# do_profile.sh: rollout profile- and some tools to yb-nodes
#
# todo: HARDcoded nodenames : make a list.
#

# set -v -x 

# nodelist="node1 node2 node3 node4 node5 node6"
nodelist="node2 node3 node4 node5 node6 node7 node8 "

for node in $nodelist
do

  echo $node : adding profile ...
  docker cp yb_profile.sh $node:/tmp/
  docker exec -it $node sh -c "cat /tmp/yb_profile.sh >> /root/.bashrc "

  # more tooling... make sure the files are in working dir

  # skip jq, libs and yum need too much space ?
  # echo $node : installing jq  ...
  # docker cp jq $node:/usr/bin/jq

  echo $node : yugatool 
  docker cp yugatool.gz $node:/home/yugabyte/bin
  cat <<EOF | docker exec -i $node sh
    gunzip /home/yugabyte/bin/yugatool.gz
    chmod 755 /home/yugabyte/bin/yugatool
    ln -s /home/yugabyte/bin/yugatool /usr/local/bin/yugatool

EOF
 
  # echo $node : zone to indicate nodename, doesnt seem to work

  # cat <<EOF | docker exec -i $node sh
  #   cat /root/var/conf/yugabyted.conf | sed s/rack1/$node/g > /tmp/yugabyte.conf
  #   cp /tmp/yugabyte.conf /root/var/conf/yugabyted.conf
  # EOF
  
  # if needed: restart to have conf take effect
 
  # docker stop $node
  # sleep 2
  # docker start $node
  # dont forget : ln -s /home/yugabyte/bin/yugatool /usr/local/bin/yugatool 

  sleep 2

done

echo .
echo nodes done: $nodelist
echo .
