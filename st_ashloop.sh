#!/bin/sh

# 27-Jul-23, pdv: start do_ashloop.sh using nohup on the platorm
#
# usage: place this file on the platform, 
# then call it via docker-exec-it
#
# reason: nohup and ampersand does not work when called in script to loop-over-nodes
#

# set -v -x

echo
echo ---- will try to start do_ahsloop.sh forever .... --- 
echo 
echo 1. check ps -ef, check nohup, which may or may not work.
echo
echo -- -- -- -- -- -- 
echo
echo


nohup /usr/local/bin/do_ashloop.sh  >> do_ashloop.log 2>&1 &

# may also need: /usr/lib64/sa/sadc -F -L -S DISK 600 30 - 

echo .
echo `date` $0 : started ashloop, verify ps -ef 
echo .
ps -ef | grep ashloo

echo
echo `date` ----  end of $0  -------- 
echo
