#!/bin/ksh
# set -v -x
#
# config_node.sh: copy all relevant data + yum-components to node, and place them..
#
# arg1 : nodename or hname (docker container to cp to..)
#
# assumption: 
#   - all files are in source-dir, 
#     unless explicitly specified.. (e.g. can use ~/.psqlrc or ~/.exrc )
#     and backtic-which should also work to find a file
#   - actions and filenames more or less hardcoded here..
#
# todo:
#  - function to do 1 file, needs 3 args: sourcefile, target-dir, and chmod ? 
#
# purpose: configure a node "just right"
#


# get some file to log stmnts, start simple
LOGFILE=config_node.log

echo .
echo `date` $0 : configuring node: \[$1 \] ... >> $LOGFILE
echo .

# 
# test: 
#  - ways to start? 
#

hname=$1

docker exec -it $hname ps -ef f 

read -t -p 'did that container exist... ?' abc

echo .
echo `date` $0 : ---- configuring node $hname  -------
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

echo $hname : adding yugatool and enabling ysql_bench...
#docker cp yugatool.gz $hname:/home/yugabyte/bin
cat <<EOF | docker exec -i $hname sh
  # gunzip /home/yugabyte/bin/yugatool.gz
  # chmod 755 /home/yugabyte/bin/yugatool
  # ln -s /home/yugabyte/bin/yugatool          /usr/local/bin/yugatool
  # ln -s /home/yugabyte/bin/yb-ts-cli           /usr/local/bin/yb-ts-cli
  ln -s /home/yugabyte/postgres/bin/ysql_bench /usr/local/bin/ysql_bench
  ln -s /home/yugabyte/postgres/bin/pg_isready /usr/local/bin/pg_isready
EOF

# echo $hname : adding jq .... Why first 
# skip jq, libs and yum need too much space ?
echo $hname : installing jq and chrony ...
# docker cp jq $hname:/usr/bin/jq
docker exec $hname yum install jq -y
docker exec $hname yum install chrony -y

echo .
echo `date` $0 : ---- tools installed node $hname  -------
echo .


# for all nodes: node-created

echo .
echo `date` $0 : ---- node configured : $hname  ------
echo . 

sleep 1

