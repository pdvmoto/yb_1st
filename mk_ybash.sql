/*

file: mk_ybash.sql: functions and tables for yb_ash and pg_stat data.
 - choose to store first + on every node, we take  insert- and select-rpc overhead..
 - useing sql-funciton for detecting hostname

usage:
 - prepare for ash-usage, check yb_flags, check blogs.
 - verify yb_active_session_history is present
 - mk_ybash.sql: to create functions + tables, 
   check for erros in case DDL changes
 - test using do_ybash.sql : can all nodes collect data ?
 - schedule for regular collection, e.g. 1min, 10min.
 - optional: have yb_init.sql done, to create helper-functions (cnt)
  
todo:
 - still duplicates in ash: wait-event-aux is sometimes only distinquiser..
   revert to id as key !
 - function to collect-per-node, then call that function from each node.
   use GET DIAGNOSTICS integer_var = ROW_COUNT; to get+return rows: Done
 - add pg_stat_statement + activity: Done
 - Q: how to relate queryid to pg_stat_activity, ask for enhancement ?
 - Q: how to relate sessionid to pid ? 
 - Q: Mechanism to run SQL on every node ? Scheduler? 
 - keep list of servers 
 - keep list of masters (how? needs ybtool or yb-admin ? and copy-stdout)
 - add copy of view  yb_local_tablets 
 - remove IDs when real keys are clear : Done
   (use ids to determine order in which data was generated?)

future questions to answer:
 - what is a good interval to measure ? (use argument in seonds or minutes?)
 - busiest node in interval (e.g. 15min?)
 - busiest table (or tablet) in interval 
 - most occuring wait-event in interval
 - can it detect xyz: locking? cpu-saturation, disk-saturation ? 
 - can we draw a lock-tree ? over mutiple nodes ? at same timestamp?
 - how to know if buffers are sufficient ? (e.g. not loose any samples)

notes:
 - to use pgbench, initiate and run pgbenh for 30sec  : 
    pgbench -i              -h localhost -p 5433 -U yugabyte yugabyte
    pgbench -T 30 -j 2 -c 2 -h localhost -p 5433 -U yugabyte yugabyte

*/ 

-- need function to get hostname

CREATE OR REPLACE FUNCTION get_host()
RETURNS TEXT AS $$
    SELECT setting
    FROM pg_settings
    WHERE name = 'listen_addresses';
$$ LANGUAGE sql;

-- Drop table
-- DROP TABLE public.ybx_ash;
-- DROP TABLE public.ybx_pgs_stmt;

CREATE TABLE public.ybx_ash (
  -- id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY, -- too many fields
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
	host text NULL,
	sample_time timestamptz  NULL,
	root_request_id uuid NULL,
	rpc_request_id int8 default 0,
	wait_event_component text NULL,
	wait_event_class text NULL,
	wait_event text NULL,
	top_level_node_id uuid NULL,
	query_id int8 NULL,
	ysql_session_id int8 NULL,
	client_node_ip text NULL,
	wait_event_aux text NULL,
	sample_weight float4 NULL,
	wait_event_type text NULL
  --, constraint ybx_ash_pk primary key ( id ) 
  --, constraint ybx_ash_pk primary key ( host HASH, sample_time ASC, root_request_id ASC, rpc_request_id ASC, wait_event asc) 
) 
split into 1 tablets
;

-- create index ybx_ash_dt on ybx_ash ( sample_time ASC, root_request_id, rpc_request_id ); 

-- statements
-- public.ybx_pgs_stmt definition

-- DROP TABLE public.ybx_pgs_stmt;

CREATE TABLE public.ybx_pgs_stmt (
  id bigint GENERATED ALWAYS AS IDENTITY, -- find pk later
  host text not null,
	userid oid NULL,
	dbid oid NULL,
	queryid int8 NULL,
	query text NULL,
	calls int8 NULL,
	total_time float8 NULL,
	min_time float8 NULL,
	max_time float8 NULL,
	mean_time float8 NULL,
	stddev_time float8 NULL,
	"rows" int8 NULL,
	shared_blks_hit int8 NULL,
	shared_blks_read int8 NULL,
	shared_blks_dirtied int8 NULL,
	shared_blks_written int8 NULL,
	local_blks_hit int8 NULL,
	local_blks_read int8 NULL,
	local_blks_dirtied int8 NULL,
	local_blks_written int8 NULL,
	temp_blks_read int8 NULL,
	temp_blks_written int8 NULL,
	blk_read_time float8 NULL,
	blk_write_time float8 NULL,
	yb_latency_histogram jsonb NULL
, constraint ybx_pgs_stmt_pk primary key  ( host, dbid, userid, queryid )
)
split into 1 tablets ;

-- store pg_stat_activity, per node + per timestamp

-- Drop table
-- DROP TABLE public.ybx_pgs_act;

CREATE TABLE public.ybx_pgs_act (
  id bigint GENERATED ALWAYS AS IDENTITY, -- find pk later
  host text not null,
  sample_time timestamptz not null,
	datid oid NULL,
	datname name NULL,
	pid int4 NULL,
	usesysid oid NULL,
	usename name NULL,
	application_name text NULL,
	client_addr inet NULL,
	client_hostname text NULL,
	client_port int4 NULL,
	backend_start timestamptz NULL,
	xact_start timestamptz NULL,
	query_start timestamptz NULL,
	state_change timestamptz NULL,
	wait_event_type text NULL,
	wait_event text NULL,
	state text NULL,
	backend_xid xid NULL,
	backend_xmin xid NULL,
	query text NULL,
	backend_type text NULL,
	catalog_version int8 NULL,
	allocated_mem_bytes int8 NULL,
	rss_mem_bytes int8 NULL,
	yb_backend_xid uuid NULL
  -- normally, host+pid are unique, only 1 qry per pid ?
  --, constraint ybx_pgs_act_pk primary key  ( id ) 
  , constraint ybx_pgs_act_pk primary key  ( host, sample_time, pid ) 
)
split into 1 tablets ;


-- collect data...  -- -- --


-- much faster using with clause ?
with h as ( select get_host () as host ) 
insert into ybx_ash  (
  host 
, sample_time 
, root_request_id 
, rpc_request_id
, wait_event_component 
, wait_event_class 
, wait_event 
, top_level_node_id 
, query_id 
, ysql_session_id  -- find related info
, client_node_ip 
, wait_event_aux
, sample_weight 
, wait_event_type 
)
  select 
  h.host as host
, a.sample_time  
, a.root_request_id  
, coalesce ( a.rpc_request_id, 0 ) 
, a.wait_event_component 
, a.wait_event_class 
, a.wait_event 
, a.top_level_node_id 
, a.query_id 
, a.ysql_session_id  -- find related info
, a.client_node_ip 
, a.wait_event_aux
, a.sample_weight 
, a.wait_event_type 
from yb_active_session_history a , h h
where not exists ( select 'x' from ybx_ash b 
                   where b.host            = h.host 
                   and   b.sample_time     = a.sample_time
                   and   b.root_request_id = a.root_request_id
                   and   b.rpc_request_id  = coalesce ( a.rpc_request_id, 0 )
                   and   b.wait_event      = a.wait_event
                 );

select host, count (*) from  ybx_ash group by host order by host ;

\d ybx_ash

-- now collect pg_stat_stmnts (and activity )
with h as ( select get_host () as host )
insert into ybx_pgs_stmt ( 
  host ,   -- check if qryid is same on host
	userid , 
	dbid , 
	queryid , 
	query , 
	calls , 
	total_time ,
	min_time  ,
	max_time  ,
	mean_time ,
	stddev_time  ,
	"rows"  ,
	shared_blks_hit  ,
	shared_blks_read  ,
	shared_blks_dirtied  ,
	shared_blks_written  ,
	local_blks_hit  ,
	local_blks_read  ,
	local_blks_dirtied  ,
	local_blks_written ,
	temp_blks_read ,
	temp_blks_written ,
	blk_read_time ,
	blk_write_time ,
	yb_latency_histogram 
)
select 
  h.host,
	userid , 
	dbid , 
	queryid , 
	query , 
	calls , 
	total_time ,
	min_time  ,
	max_time  ,
	mean_time ,
	stddev_time  ,
	"rows"  ,
	shared_blks_hit  ,
	shared_blks_read  ,
	shared_blks_dirtied  ,
	shared_blks_written  ,
	local_blks_hit  ,
	local_blks_read  ,
	local_blks_dirtied  ,
	local_blks_written ,
	temp_blks_read ,
	temp_blks_written ,
	blk_read_time ,
	blk_write_time ,
	yb_latency_histogram 
from pg_stat_statements s
   , h h
where 1=1
and not exists ( select 'x' from ybx_pgs_stmt y
                 where y.host = h.host
                 and   y.dbid = s.dbid
                 and   y.userid = s.userid
                 and   y.queryid = s.queryid
) ;
;

-- collect acitivity..

with h as ( select get_host () as host )
insert into ybx_pgs_act (
  host ,
  sample_time ,
  datid ,
  datname ,
  pid ,
  usesysid ,
  usename ,
  application_name ,
  client_addr ,
  client_hostname ,
  client_port ,
  backend_start ,
  xact_start ,
  query_start ,
  state_change ,
  wait_event_type ,
  wait_event ,
  state ,
  backend_xid ,
  backend_xmin ,
  query ,
  backend_type ,
  catalog_version ,
  allocated_mem_bytes ,
  rss_mem_bytes ,
  yb_backend_xid 
)
select 
  h.host, 
  now() ,
  datid ,
  datname ,
  pid ,
  usesysid ,
  usename ,
  application_name ,
  client_addr ,
  client_hostname ,
  client_port ,
  backend_start ,
  xact_start ,
  query_start ,
  state_change ,
  wait_event_type ,
  wait_event ,
  state ,
  backend_xid ,
  backend_xmin ,
  query ,
  backend_type ,
  catalog_version ,
  allocated_mem_bytes ,
  rss_mem_bytes ,
  yb_backend_xid
from pg_stat_activity a, h h ;
-- no where clause at all ?

select host, count (*) from ybx_pgs_act group by host order by host ;



/*

function : ybx_get_ash();

collect ash + pg_stat_stmnts + pg_stat_activity for current node
returns total nr of records

*/ 

-- function 

CREATE OR REPLACE FUNCTION ybx_get_ash()
  RETURNS bigint
  LANGUAGE plpgsql 
AS $$
DECLARE
  nr_rec_processed bigint := 0 ;
  retval bigint := 0 ;
BEGIN

-- collect data...  -- -- --

-- much faster using with clause ?
with h as ( select get_host () as host ) 
insert into ybx_ash  (
  host 
, sample_time 
, root_request_id 
, rpc_request_id
, wait_event_component 
, wait_event_class 
, wait_event 
, top_level_node_id 
, query_id 
, ysql_session_id  -- find related info
, client_node_ip 
, wait_event_aux
, sample_weight 
, wait_event_type 
)
  select 
  h.host as host
, a.sample_time  
, a.root_request_id  
, coalesce ( a.rpc_request_id, 0 ) 
, a.wait_event_component 
, a.wait_event_class 
, a.wait_event 
, a.top_level_node_id 
, a.query_id 
, a.ysql_session_id  -- find related info
, a.client_node_ip 
, a.wait_event_aux
, a.sample_weight 
, a.wait_event_type 
from yb_active_session_history a , h h
where not exists ( select 'x' from ybx_ash b 
                   where b.host            = h.host 
                   and   b.sample_time     = a.sample_time
                   and   b.root_request_id = a.root_request_id
                   and   b.rpc_request_id  = coalesce ( a.rpc_request_id, 0 )
                   and   b.wait_event      = a.wait_event
                 );

GET DIAGNOSTICS nr_rec_processed := ROW_COUNT;
retval := retval + nr_rec_processed ;

-- now collect pg_stat_stmnts (and activity )
with h as ( select get_host () as host )
insert into ybx_pgs_stmt ( 
  host ,   -- check if qryid is same on host
	userid , 
	dbid , 
	queryid , 
	query , 
	calls , 
	total_time ,
	min_time  ,
	max_time  ,
	mean_time ,
	stddev_time  ,
	"rows"  ,
	shared_blks_hit  ,
	shared_blks_read  ,
	shared_blks_dirtied  ,
	shared_blks_written  ,
	local_blks_hit  ,
	local_blks_read  ,
	local_blks_dirtied  ,
	local_blks_written ,
	temp_blks_read ,
	temp_blks_written ,
	blk_read_time ,
	blk_write_time ,
	yb_latency_histogram 
)
select 
  h.host,
	userid , 
	dbid , 
	queryid , 
	query , 
	calls , 
	total_time ,
	min_time  ,
	max_time  ,
	mean_time ,
	stddev_time  ,
	"rows"  ,
	shared_blks_hit  ,
	shared_blks_read  ,
	shared_blks_dirtied  ,
	shared_blks_written  ,
	local_blks_hit  ,
	local_blks_read  ,
	local_blks_dirtied  ,
	local_blks_written ,
	temp_blks_read ,
	temp_blks_written ,
	blk_read_time ,
	blk_write_time ,
	yb_latency_histogram 
from pg_stat_statements s
   , h h
where 1=1
and not exists ( select 'x' from ybx_pgs_stmt y
                 where y.host = h.host
                 and   y.dbid = s.dbid
                 and   y.userid = s.userid
                 and   y.queryid = s.queryid
) 
;

GET DIAGNOSTICS nr_rec_processed := ROW_COUNT;
retval := retval + nr_rec_processed ;

-- collect acitivity..

with h as ( select get_host () as host )
insert into ybx_pgs_act (
  host ,
  sample_time ,
  datid ,
  datname ,
  pid ,
  usesysid ,
  usename ,
  application_name ,
  client_addr ,
  client_hostname ,
  client_port ,
  backend_start ,
  xact_start ,
  query_start ,
  state_change ,
  wait_event_type ,
  wait_event ,
  state ,
  backend_xid ,
  backend_xmin ,
  query ,
  backend_type ,
  catalog_version ,
  allocated_mem_bytes ,
  rss_mem_bytes ,
  yb_backend_xid 
)
select 
  h.host, 
  now() ,
  datid ,
  datname ,
  pid ,
  usesysid ,
  usename ,
  application_name ,
  client_addr ,
  client_hostname ,
  client_port ,
  backend_start ,
  xact_start ,
  query_start ,
  state_change ,
  wait_event_type ,
  wait_event ,
  state ,
  backend_xid ,
  backend_xmin ,
  query ,
  backend_type ,
  catalog_version ,
  allocated_mem_bytes ,
  rss_mem_bytes ,
  yb_backend_xid
from pg_stat_activity a, h h ;
-- no where clause at all ?

GET DIAGNOSTICS nr_rec_processed := ROW_COUNT;
retval := retval + nr_rec_processed ;

  -- end of fucntion..
  return retval ;

END;
$$
;

-- call function and compare counts to test

select 
  (select count (*) ash   from ybx_ash      ) ash
, (select count (*) stmts from ybx_pgs_stmt ) stmts
, (select count (*) activ from ybx_pgs_act  ) activ ;
 
select ybx_get_ash () collect_function_called; 

select 
  (select count (*) ash   from ybx_ash      ) ash
, (select count (*) stmts from ybx_pgs_stmt ) stmts
, (select count (*) activ from ybx_pgs_act  ) activ ;
 
