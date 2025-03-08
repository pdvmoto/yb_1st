#!/bin/bash

# yb_boot.sh: boot the yuga processes, useing yugabyted stop/start. 
#
# usage; copy to each node and start on the machine, using docker exec or do_all.sh
# 
# todo:
#   - remove sockers on /tmp
#

# a bit quick
N_SECS=2


echo $0 `date` `hostname` rebooting yugabyte ----------- 
echo .

yugabyted stop 

sleep $N_SECS

yugabyted start

echo $0 `date` `hostname` yb restarted ----------------
echo .
