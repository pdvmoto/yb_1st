#!/usr/bin/sh

# get_metr.sh : extract a few metrics from port

echo $0 running on : $HOSTNAME

curl ${HOSTNAME}:7000/prometheus-metrics?show_help=false > /tmp/mast.out
curl ${HOSTNAME}:9000/prometheus-metrics?show_help=false > /tmp/tsrv.out

cat /tmp/tsrv.out | sed 's/{/\|/g' | sed 's/} /\|/g' | sed 's/ /\|/g' \
  | awk -F'|' ' {print $1, $3 }'  | grep -i cpu | grep -v Brocksdb > /tmp/tsrv.mtr 

cat /tmp/mast.out | sed 's/{/\|/g' | sed 's/} /\|/g' | sed 's/ /\|/g' \
  | awk -F'|' ' {print $1, $3 }'  | grep -i cpu | grep -v Brocksdb > /tmp/mast.mtr 
ysqlsh -h ${HOSTNAME} -X <<EOF

	select 'try copy here.. ' ;

	-- set start
	SELECT extract(epoch FROM now())::float AS start_dt \gset

	-- make sure empty
	delete from ybx_kvlog where host = ybx_get_host () ;

	COPY ybx_kvlog(key, value)
	FROM '/tmp/mast.mtr'
	WITH (FORMAT text, DELIMITER ' ', HEADER false, NULL '');

	select * from ybx_kvlog ; 


	-- make sure empty
	delete from ybx_kvlog where host = ybx_get_host () ;

	COPY ybx_kvlog(key, value)
	FROM '/tmp/tsrv.mtr'
	WITH (FORMAT text, DELIMITER ' ', HEADER false, NULL '');

	select * from ybx_kvlog ; 

EOF




