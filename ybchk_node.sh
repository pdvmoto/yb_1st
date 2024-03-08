#!/bin/sh

# ybchk_node.sh: update or add node specific data to the ybx_chk tables, notably IP

# set -v -x

nodename=`hostname`

ysqlsh -h $nodename -X <<EOL

update ybx_chknode
  set public_ip = inet_server_addr()
  where run_id = ( select max (id) from ybx_chkrun )
  and host = '$nodename' ;

EOL

echo .
echo updated ip for node $nodename
echo .
