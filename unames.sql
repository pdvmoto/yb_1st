
delete from ybx_kvlog where host = ybx_get_host () ; 

-- need to go via file, bcse curl does not seem to work well if "from program"
\! /tmp/unames.sh > /tmp/abc.out 

COPY ybx_kvlog(key, value)
FROM '/tmp/abc.out'
WITH (FORMAT text, DELIMITER '=', HEADER false, NULL '');

-- verify raw data
select * from ybx_kvlog where host = ybx_get_host();

-- verify transfer data
with 
  gh as ( select ybx_get_host() as host)
, pr as ( select value from ybx_kvlog kv, gh where kv.host = gh.host and key = 'nr_processes' )
, mm as ( select value from ybx_kvlog kv, gh where kv.host = gh.host and key = 'master_mem' )
, tm as ( select value from ybx_kvlog kv, gh where kv.host = gh.host and key = 'tserver_mem' )
, du as ( select value from ybx_kvlog kv, gh where kv.host = gh.host and key = 'disk_usage_mb' )
, ti as ( select value from ybx_kvlog kv, gh where kv.host = gh.host and key = 'top_info' )
select gh.host
, pr.value::int		nr_processes
, mm.value::bigint 	master_mem
, tm.value::bigint 	tserver_mem
, du.value::bigint 	disk_usage_mb
, ti.value 		top_info
from gh gh
, pr pr 
, mm mm
, tm tm
, du du
, ti ti
; 

-- do transfer to log-table 
-- note the intrinsic convesion to some numbers...
with 
  gh as ( select ybx_get_host() as host)
, pr as ( select value from ybx_kvlog kv, gh where kv.host = gh.host and key = 'nr_processes' )
, mm as ( select value from ybx_kvlog kv, gh where kv.host = gh.host and key = 'master_mem' )
, tm as ( select value from ybx_kvlog kv, gh where kv.host = gh.host and key = 'tserver_mem' )
, du as ( select value from ybx_kvlog kv, gh where kv.host = gh.host and key = 'disk_usage_mb' )
, ti as ( select value from ybx_kvlog kv, gh where kv.host = gh.host and key = 'top_info' )
insert into ybx_host_log ( host, nr_processes, master_mem, tserver_mem, disk_usage_mb, top_info )
select gh.host
, pr.value::int 	nr_processes
, mm.value::bigint 	master_mem
, tm.value::bigint 	tserver_mem
, du.value::bigint 	disk_usage_mb
, ti.value 		top_info
from gh gh
, pr pr 
, mm mm
, tm tm
, du du
, ti ti
; 

select * from ybx_host_log ; 

-- cleanup, it is temporary data after all
-- delete from ybx_kvlog where host = ybx_get_host() ; 

