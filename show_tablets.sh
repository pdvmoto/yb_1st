#!/bin/sh

# show_tabets.sh : table_name
#
# assume table is in database yugabyte: ysql.yugabyte
# list tablets
# then list reaplicas from tablets using tablet_uuid , separate scripts..

yb-admin -master_addresses $MASTERS list_tablets ysql.yugabyte $1 0

# now use tablet uuid: to list replicas
# yb-admin -master_addresses $MASTERS list_tablet_servers <tablet_uuid). 




