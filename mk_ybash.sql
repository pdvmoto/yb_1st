/*

file: mk_ybash.sql: functions and tables for yb_ash and pg_stat data.
 - choose to store first + on every node, we take  insert- and select-rpc overhead..
 - useing sql-funciton for detecting hostname

usage:
 - prepare for ash-usage, include yb_flags, check blogs.
 - verify the view yb_active_session_history is present
 - run script \i mk_ybash.sql: to create functions + tables, 
   check for erros in case DDL changes
 - test using do_ybash.sql : can all nodes collect data ?
 - schedule for regular collection, e.g. 1min, 10min.: do_ashloop.sh
 - optional: check to have yb_init.sql done, reate helper-functions (cnt)
 
todo, high level.
 - reports: find top-consumers
 - reports: zoom in, tree, or hierarchy.. despite yb-claim..
 - report + data: why sometimes 25K reords per minute?? what kind of events?
 - try logging "sessions" from client_node_ip: create_dt and gone_dt, or sess_id
 - link ahs to activity, qry-text not the same, with/out $n substitutes
 - link ash to pg_stat_statements with query_id
 - save pg_stat_stmt + metrics (2 tables: stmnt_id, and id+metrics_in_interval)

todo:
 - check TEST_ash flag.. try out ?
 - check load of metrics-curling.. http://localhost:9004/prometheus-metrics
 - spot ClientRead as passive status ?  : no proof.. forget it for now
 - test on colocated db: only 1 tablet, and 1 table-name. complicated..?  hmm
 - still duplicates in ash: wait-event-aux is sometimes only distinquiser..
   revert to id as key !
 - speed up insertions into logtables with indexes, host+ sample_time
 - types: tservers().uuid is txt, top-level is uuid.. mix of types
 - pg_stat_statement: needs re-think. for exmpl, save every "interval" and reset
 - pg_stat_statement; could use a timestamp of "date-time found"
 - pg_stat_statement: consider merge with new stats every 10min ? 
 - split get_ash() in  3 : ash, pg_stat_statments, and pg_stat_activity
 - get_ash(): output text: added n records, in m ms.
 - Q: how to relate queryid to pg_stat_activity, ask for enhancement ?
 - Q: how to relate sessionid to pid ? 
 - Q: Mechanism to run SQL on every node ? Scheduler? 
 - keep list of servers, detect when server is down? - scrape from ybadmin?
 - keep list of masters (how? needs ybtool or yb-admin ? and copy-stdout)
 - yb_local_tablets, to Separate SCript, and detect down-nodes/moved tblts
 - Q: detect migrated + dropped tablets, and dissapeared nodes. how ???
 - use dflts for host and timestamp in DDL?
 - Q: should we introcude a snap_id (snapshot) 
   to link related data to 1 event or 1 point-in-time ?
 - need a repeatable "load generator", notaby IO-write and IO-read.
    mk_longt.sql? 
 - collect new wait_events in do_ashloop, or similar place
 - script: wheris.sql: tablet or table, and list the nodes where it is/was.
 - script: yb_ash_int.sql: generate report for interval, define in top of file
 - script: yb_ash_topsql.sql: list most found SQL., per count, per mem, per rows, per calls.
 - t_long2.: insert a lot of data, generate long tx, long sql.
 - collect mem per snapshot: sum (pg_stat_act)
 - use count + interval of 'OnCpu_Passive' to find cpu-saturation? 

more todo
 - get 1 benchmark, and test.., need tables of 2G or more to really hammer..
 - standardize test-results: use script to report on cutoff-interval 
 - compare with mapped volumes and local-docker volumes
 - compare with more docker-rerouces: more cpus: not a success.
 - compare with smaller interval, say 100ms: not on mac-docker, cpu loaded..
 - test with fresh-start cluster: clean memory ? 
 - test with 1 or more nodes down + up. watch redistribution ?
 - Idle, ClientRead etc: make a list of Idle events
 - log yb-admin masters and tservers

todo logging
 - is tx-asc a good pk ?

items done:
 - Schedule collection, say 5min loops: do_ashloop.sh seems to work. test.
 - function to collect-per-node, then call that function from each node.
   use GET DIAGNOSTICS integer_var = ROW_COUNT; to get+return rows: Done
 - add pg_stat_statement + activity: Done
 - remove IDs when real keys are clear : Done
   (use ids to determine order in which data was generated?)
 - add copy of view  yb_local_tablets - ok, move to Separate SCript!
 - adding nohup-loop to run ash-collection : do_ashloop.sh + start_ashloop.sh
 - ashrep.sql : use script with nr-seconds to list top-events? : done
 - eventlist: in do_ashrep.sql, Add regular detection of new event-names: done
 - parameters inteval + buffersizes to flagfile, but work with dflts.


future questions to answer:
 - what is a good interval to measure ? (use argument in seonds or minutes?)
 - busiest node in interval (e.g. 15min?)
 - busiest table (or tablet) in interval 
 - most occuring wait-event in interval
 - can it detect xyz: locking? cpu-saturation, disk-saturation ? 
 - can we draw a lock-tree ? over mutiple nodes ? at same timestamp?
 - how to know if buffers are sufficient ? (e.g. not loose any samples)

notes:
 - to use pg, initiate and run pgbenh for 30sec  : 
    pgbench -i              -h localhost -p 5433 -U yugabyte yugabyte
    pgbench -T 30 -j 2 -c 2 -h localhost -p 5433 -U yugabyte yugabyte

 - to use ysql_bench, initiate and run pgbenh for 30sec  : 
    /home/yugabyte/postgres/bin/ysql_bench -i              -h $HOSTNAME -p 5433 -U yugabyte yugabyte
    /home/yugabyte/postgres/bin/ysql_bench -T 30 -j 2 -c 2 -h $HOSTNAME -U yugabyte yugabyte

 - try for a hierarchy, find top-stateent, and events below it..

*/ 

-- need function to get hostname

CREATE OR REPLACE FUNCTION get_host()
RETURNS TEXT AS $$
    SELECT setting
    FROM pg_settings
    WHERE name = 'listen_addresses';
$$ LANGUAGE sql;

/*  Drop tables
  DROP TABLE public.ybx_ash;
  DROP TABLE public.ybx_pgs_stmt;
  DROP TABLE public.ybx_tblt;
*/

/* generic logging..
-- drop table public.ybx_log ;  
*/

create table ybx_log (
    id          bigint        generated always as identity  
  , logged_dt   timestamptz   not null
  , host text 
  , component text
  , ela_ms double precision 
  , info_txt text 
  , constraint ybx_log_pk primary key (logged_dt asc, id  asc)  
  );
 

CREATE TABLE public.ybx_ash (
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

-- create index ybx_ash_dt  on ybx_ash ( sample_time ASC, root_request_id, rpc_request_id ); 
   create index ybx_ash_key on ybx_ash ( sample_time asc, host, root_request_id, rpc_request_id, wait_event ) ; 

create index ybx_ash_host on ybx_ash ( host, sample_time asc ) ; 


-- DROP TABLE public.ybx_pgs_stmt;

CREATE TABLE public.ybx_pgs_stmt (
  id bigint GENERATED ALWAYS AS IDENTITY, -- find pk later
  host text not null,
  created_dt timestamptz default now(),
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


-- collect tablet info...

-- DROP TABLE public.ybx_tblt;

CREATE TABLE public.ybx_tblt (
  id bigint GENERATED ALWAYS AS IDENTITY primary key, -- find pk later
  host text not null,
  sample_time timestamptz not null, -- not same as ash-sampletime 
  gone_time timestamptz,            -- use to signal removal 
	tablet_id text NULL,
	table_id text NULL,
	table_type text NULL,
	namespace_name text NULL,
	ysql_schema_name text NULL,
	table_name text NULL,
	partition_key_start bytea NULL,
	partition_key_end bytea NULL
)
split into 1 tablets ;

-- collect generic info

-- drop table ybx_log ; 

create table ybx_log (
    id bigint generated always as identity  
  , logged_dt timestamptz not null
  , host text 
  , component text
  , info_txt text 
  , constraint ybx_log_pk primary key (logged_dt asc, id  asc)  
  );
 




/* ******** collection of data via inserts.. moved to functions ****

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

-- collect local_tablets, move to separate function and script later.

with h as ( select get_host () as host ) 
insert into ybx_tblt (
  skip-smtnt,
  host ,
  sample_time ,
  gone_time , 
	tablet_id ,
	table_id ,
	table_type ,
	namespace_name ,
	ysql_schema_name ,
	table_name ,
	partition_key_start ,
	partition_key_end 
)
select 
  h.host ,
  now() ,
  null , -- update gone_time when no longer found 
	tablet_id ,
	table_id ,
	table_type ,
	namespace_name ,
	ysql_schema_name ,
	table_name ,
	partition_key_start ,
	partition_key_end 
from yb_local_tablets t, h h 
where not exists (
  select 'x' from ybx_tblt u
  where h.host = u.host
  and   t.tablet_id = u.tablet_id
  and   u.sample_time is null  -- catch moving + returning tablets 
  ) ; 

-- signal if tblt no longer on this host.
with h as ( select get_host () as host )
update ybx_tblt t set gone_time = now ()
, skip_stmnt
where not exists (  -- skip
  select 'x' from yb_local_tablets l, h h
  where h.host = t.host
  and   l.tablet_id = t.tablet_id
  ) ;

*/


/* *****************************************************************

function : ybx_get_ash();

collect ash + pg_stat_stmnts + pg_stat_activity for current node
returns total nr of records

*/ 

CREATE OR REPLACE FUNCTION ybx_get_ash()
  RETURNS bigint
  LANGUAGE plpgsql 
AS $$
DECLARE
  nr_rec_processed BIGINT         := 0 ;
  start_dt      timestamp         := clock_timestamp();
  end_dt        timestamp         := now() ;
  duration_ms   double precision  := 0.0 ;
  retval bigint := 0 ;
BEGIN

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
                   and   b.sample_time > ( now() - make_interval ( secs=>1800 ) )
                 );

GET DIAGNOSTICS nr_rec_processed := ROW_COUNT;
retval := retval + nr_rec_processed ;

RAISE NOTICE 'get_ash() yb_act_sess_hist : % ' , nr_rec_processed ; 

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
RAISE NOTICE 'get_ash() pg_stat_stmnts   : % ' , nr_rec_processed ; 

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
RAISE NOTICE 'get_ash() pg_stat_activity : % ' , nr_rec_processed ; 
    
duration_ms := EXTRACT ( MILLISECONDS from ( clock_timestamp() - start_dt ) ) ; 

RAISE NOTICE 'get_ash() elapsed : % ms'     , duration_ms ; 

insert into ybx_log ( logged_dt, host,       component,     ela_ms,      info_txt )
       select clock_timestamp(), get_host(), 'ybx_get_ash', duration_ms, 'logging duration of test' ; 

-- end of fucntion..
return retval ;

END; -- get_ash, to incrementally populate table
$$
;


/*

function : get_tablets();

collect ybx_tblt with local tablets, local to current node
returns total nr of records inserted and updated

*/

CREATE OR REPLACE FUNCTION get_tablets()
  RETURNS bigint
  LANGUAGE plpgsql
AS $$
DECLARE
  nr_rec_processed bigint         := 0 ;
  start_dt      timestamp         := clock_timestamp();
  end_dt        timestamp         := now() ;
  duration_ms   double precision  := 0.0 ;
  retval bigint                   := 0 ;
BEGIN

-- insert any new-found tablets on this node...
with h as ( select get_host () as host )
insert into ybx_tblt (
  host ,
  sample_time ,
  gone_time ,
  tablet_id ,
  table_id ,
  table_type ,
  namespace_name ,
  ysql_schema_name ,
  table_name ,
  partition_key_start ,
  partition_key_end
)
select
  h.host ,
  now() ,
  null , -- update gone_time when no longer found 
  tablet_id ,
  table_id ,
  table_type ,
  namespace_name ,
  ysql_schema_name ,
  table_name ,
  partition_key_start ,
  partition_key_end
from yb_local_tablets t, h h
where not exists (
  select 'x' from ybx_tblt u
  where h.host      =  u.host
  and   t.tablet_id =  u.tablet_id
  and   u.gone_time is null  --  catch moving + returning tablets 
  ) ;

GET DIAGNOSTICS nr_rec_processed := ROW_COUNT;
retval := retval + nr_rec_processed ;
RAISE NOTICE 'get_tblts() created : % tblts' , nr_rec_processed ; 

-- update the gone_date if tablet no longer present..
-- signal gone_date if ... gone
with h as ( select get_host () as host )
update ybx_tblt t set gone_time = now () 
where 1=1 
and   t.gone_time  is null                   -- no end time yet
and   t.host       in ( select host from h ) -- same host
and not exists (                             -- no more local tblt
  select 'x' from yb_local_tablets l
  where   t.tablet_id  =  l.tablet_id 
  )
;

GET DIAGNOSTICS nr_rec_processed := ROW_COUNT;
retval := retval + nr_rec_processed ;

duration_ms := EXTRACT ( MILLISECONDS from ( clock_timestamp() - start_dt ) ) ; 

RAISE NOTICE 'get_tblts() gone    : % tblts'  , nr_rec_processed ; 
RAISE NOTICE 'get_tblts() elapsed : % ms'     , duration_ms ; 

insert into ybx_log ( logged_dt, host,       component,     ela_ms,      info_txt )
       select clock_timestamp(), get_host(), 'get_tablets', duration_ms, 'logging duration of test' ; 

  -- end of fucntion..
  return retval ;

END; -- function get_tblts: to get_tablets
$$
;



-- call functions and compare counts to test

select 
  (select count (*) ash   from ybx_ash      ) ash
, (select count (*) stmts from ybx_pgs_stmt ) stmts
, (select count (*) activ from ybx_pgs_act  ) activ ;
 
select ybx_get_ash () collect_function_called; 

select 
  (select count (*) ash   from ybx_ash      ) ash
, (select count (*) stmts from ybx_pgs_stmt ) stmts
, (select count (*) activ from ybx_pgs_act  ) activ ;
 
-- and tablets..
select count (*) tablets_detected, host from ybx_tblt group by host ;

select get_tablets () as nr_tablets_processed ;

select count (*) tablets_detected, host from ybx_tblt group by host ;

