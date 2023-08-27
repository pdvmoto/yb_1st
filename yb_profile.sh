# 
# yb-profile.sh: useful additions to (bash-)profile
# add to /root/.bashrc, use do_all.sh ?
#
export MASTERS=`cat /root/var/conf/yugabyted.conf | grep masters | cut -b25-71 `
alias     ll='ls -la '
alias    ltm='ls -ltra ' 
alias    ysl='ysqlsh -h $HOSTNAME -U yugabyte ' 
alias    yba='yb-admin -master_addresses $MASTERS '
alias ybuniv='yb-admin -master_addresses $MASTERS get_universe_config '
alias ybmast='yb-admin -master_addresses $MASTERS list_all_masters '
alias ybtsrv='yb-admin -master_addresses $MASTERS list_all_tablet_servers '
alias ybtrep='yb-admin -master_addresses $MASTERS list_tablet_servers '
alias ybtbls='yb-admin -master_addresses $MASTERS list_tables  include_db_type include_table_id include_table_type | sed s'/\./\ /g' '


