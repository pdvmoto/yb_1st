#!/bin/ksh

# set env $MASTERS to masterlist from node1.
#
# beware: only works if .conf file is present at given location, and only with 3nodes
#
# future: use jq:
# cat yugabyted.conf | jq -r '.current_masters'  
#

export MASTERS=`docker exec -it node1 cat /root/var/conf/yugabyted.conf | grep masters | cut -b25-71 `

