
/* 

file: mk_ybash.sql: functions and tables for yb_ash and pg_stat data.
 - note: this one now adjusted or pg15.. for v11: see ..._v11.sql
 - choose to store first + on every node, 
   we take  insert- and select-rpc overhead..
 - useing sql-funciton for detecting hostname

usage:
 - prepare for ash-usage, include yb_flags, check blogs.
 - verify the view yb_active_session_history is present
 - run script \i mk_ybash.sql: to create functions + tables, 
   check for erros in case DDL changes
 - verify cronjob for ybx_get_tablog(), (consider moving to do_snap.sh)
 - schedule for regular collection, e.g. 1min, 10min.: do_ashloop.sh
 - run mk_osdata.sql to create more tables, host, mast, tsrv, univ
 - include unames.sh and unames.sql
 - include do_snap.sh on ONE node.
 - optional: check to have yb_init.sql done on other dbids, create helper-functions (cnt)
 - optional: add \i mk_ashvws.sql for the gv views from Frankc.
 - 

todo, high level.
 - for V15, re-check PKs, notably ysql_dbid ? check on insert-key?
 - to connect ash to sessions: store client_addr and client_port: split_part.. 
    - not yet: for the moment ash.pid => client-pid on top_level_node_id
 - log database stats.. datb_mst and datb_log : done
 - consider separate database for deployment, db_util ? 
 - need datamodel: 
    - store once: universe, cluster, node, master, tsever...  ybx_abcd_mst
    - then add log-records per time or per snapshot?          ybx_abcd_log
    - add FKs to/from tables - tablets - host
    - found_dt, log_dt, gone_dt : consistent names            sample_dt or log_dt
    - uuid or text ??? yb_servers.uuid : text.. but ash.top_level_node_id and yb-admin: text.
    - consider abstracting sessions (+log), root_events (+log), queries (+log)
 - queries: 1 query_id (qury_mst), can have many root_requests From diff tsever, 
    - quer_mst + quer_log (with fk to sess_mst) needed, qry-stats should be logged until... 
    - check: does a root_req only have one query_id ? (pg_stmnt_log = top?)
 - root_req: can generate an ash_events on several nodes.
    - duration of root_req can be measured on originating node. (top_server_uuid)
    - how to know if a root_req is finished ? (not exist )
 - session: sess_mst = tsrv_uuid(host) + pid + backend_start_dt, 
    - then generates sess_log records from pg_stats_activity for as long as it lives
 - save table-sizes: pg_tables, oid, dt_found, size-mb, table_uuid [, num_tablets..]
    but only save new records when data changes.. => ybx_get_tablogs is too slow.. reduce Freq..
    better schedule via cron (now done!) bcse 1 node can do ybx_get_tablog
 - blog: save data in tables, then qry if needed.. only pick most recent data from mem.
   - add code + examples, notably interval
 - simplify deployment, merge mk_osdata + collect scripts.
    - consider separate db: sysaux , owner ybash..? 
 - test with masters on separate nodes, see where activity goes.
    sar shows equal activity, but top shows activ only on nodes with tablets..
 - grafana: use qries with time (minute) and metrics.. 
    - save SQL for graphana dashboards
 - grafana: use qries with count per stmnt (over last x min), and display top stmnt.
 - reports: find top-consumers
 - reports: zoom in, tree, or hierarchy.. despite yb-claim..
 - report + data: why sometimes 25K reords per minute?? what kind of events?
 - try logging "sessions" from client_node_ip: create_dt and gone_dt, or sess_id
 - to connect to sessions: store client_addr and client_port: split_part..
 - link ahs to activity, qry-text not the same, with/out $n substitutes
 - save pg_stat_stmt + metrics (2 tables: stmnt_id, and id+metrics_in_interval)
 - detect tablets that have moved, try finding "where to" or "where from"
 - detect tablets on non-existing nodes.. close them..  (gone_time, closed by self or other...)? 

 - log AAS per database, quick win:
    select d.datname 
    , d.session_time, d.active_time -- use Delta once logging is on possible
    ,   round (d.active_time::numeric / (d.session_time+0.1)::numeric, 3) aas
    , d.* 
    from pg_catalog.pg_stat_database d; 

todo:
 - find uuid of local tserver. similr to ybx_get_host(). Find "where we are"
 - some fuctions a bit slow, find out why.
 - isolate pg_cron items in separate file, in case not present
 - blacklist works, but yb_local_tablets sometimes 0, sometimes not. thombstoned ?
 - speed up insert query get_ash_1, limit to check only last 900 sec, but seems to fail
 - invalid byte sequence: some type conversion in get_ash ?
 - check load of metrics-curling.. http://localhost:9004/prometheus-metrics
 - spot ClientRead as passive status ?  : no proof.. forget it for now
 - test on colocated db: only 1 tablet, and 1 table-name. complicated..?  hmm
 - unique key, still duplicates in ash: wait-event-aux is sometimes only distinquiser..
   revert to id as key !
 - speed up insertions into logtables with indexes, host+ sample_time
 - pg_stat_statement: needs re-think. for exmpl, save every "interval" and reset
 - pg_stat_statement; could use a timestamp of "date-time found"
 - pg_stat_statement: consider merge with new stats every 10min ? 
 - split get_ash() in  3 : ash, pg_stat_statments, and pg_stat_activity
 - Q: how to relate sessionid to pid ? : ybx_sess_mst (but min-start_date..) 
 - Q: Mechanism to run SQL on every node ? Scheduler? : do_ashloop.sh, not quite good
 - keep list of servers, detect when server is down? - scrape from ybadmin?
 - keep list of masters (how? needs ybtool or yb-admin ? and copy-stdout): do_snap.sh
 - store class-oid with tablets 
 - Q: detect migrated + dropped tablets, and dissapeared nodes. how ???
 - use dflts for host and timestamp in DDL?
 - Q: should we introcude a snap_id (snapshot) 
   to link related data to 1 event or 1 point-in-time ? : 
    - snap_id seems of limited use.. data is logged over hosts, and snap_id sequence contains holes
 - need a repeatable "load generator", notaby IO-write and IO-read.
    - mk_longt.sql and tlong.sql are sort-of useful.. need ysql_bench to work with pg-15? 
 - script: wheris.sql: tablet or table, and list the nodes where it is/was.
 - script: yb_ash_int.sql: generate report for interval, define in top of file
 - script: yb_ash_topsql.sql: list most found SQL., per count, per mem, per rows, per calls.
 - t_long2.: insert a lot of data, generate long tx, long sql.
 - collect mem per snapshot: sum (pg_stat_act): better: yb_servers_metrics().
 - use count + interval of 'OnCpu_Passive' to find cpu-saturation? 

todo on tablets: improve monitoring and logic
 - yb_local_tablets, to Separate SCript, and detect down-nodes/moved tblts
 - yb_local_tablets: state=ok,suspect,gone, depending on node and last-seen?
 - store class-oid of table with tablets (why? not urgen?)
 - find Master-tserver (node or uuid) for tablet, how? : do_snap.sh
 - yb_local_tablets: leader, boolean, needed. how to Find it ?

more todo
 - get 1 benchmark, and test.., need tables of 2G or more to really hammer..
 - standardize test-results: use script to report on cutoff-interval 
 - compare with mapped volumes and local-docker volumes
 - compare with more docker-resources: more cpus: not a success.
 - compare with smaller interval, say 100ms: not on mac-docker, cpu loaded..
 - test with fresh-start cluster: clean memory ? 
 - test with 1 or more nodes down + up. watch redistribution ?
 - Idle, ClientRead etc: make a list of Idle events
 - log yb-admin masters and tservers: done

todo on rewrite:
 - all logging tables created in 1 script (add mk_osdata.sql ) 
 - collect-scripts: 
    1- ashloop, call fuctions, per server. 
    2- unames.sh/sql per server, need shell
    2- tablog: via cron ? later add to do_snap.sh, need only 1 per cluster
    3- do_snap: 1-per-cluseter not via crontab, bcse shell needed
 - use uuid or text, but only 1 type.. (prfer uuid, more efficient ? )
 
todo logging
 - is tx-asc a good pk ?

items done:
 - report of 15min, from gv. find busy minutes, find top-events, find top-consumers.
    done: yb_ashrep.sh [ arg1 [ arg2 ] ] 
 - Schedule collection, say 5min loops: do_ashloop.sh seems to work. test.
   startsadc.sh, st_ashloop.sh
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
 - rewrite deployent, functions, timers, and call-for-1-node scripts: +/- ok


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

 - pg_stat_statements: 
    - needs to be reset from time 2time..
    - contains cumulative values, better to sample every 15 min or so, and keep data with sample-time.

-- notes on grafana ..

how to graphana..
Add dashboard, add visualization, query => builder, and paste the SQL, 
with a time-component as first field..

Queries like these work:

select  date_trunc( 'seconds' , sample_time) as dt 
, sum ( case a.wait_event_class when 'YSQLQuery' then 1 else 0 end ) as YQry
, sum ( case a.wait_event_class when 'Common' then 1 else 0 end ) as Common
, sum ( case a.wait_event_class when 'TServerWait' then 1 else 0 end ) as TServer
, sum ( case a.wait_event_class when 'TabletWait' then 1 else 0 end ) as TabletWait
, sum ( case a.wait_event_class when 'Consensus' then 1 else 0 end ) as Consensus
, sum ( case a.wait_event_class when 'Client' then 1 else 0 end ) as Cliet
, sum ( case a.wait_event_class when 'RocksDB' then 1 else 0 end ) as RocksDB
from ybx_ash a
group by 1 

select  date_trunc( 'seconds' , sample_time) as dt 
, sum ( case a.wait_event_type when 'Cpu' then 1 else 0 end ) as CPU
, sum ( case a.wait_event_type when 'WaitOnCondition' then 1 else 0 end ) as WonCond
, sum ( case a.wait_event_type when 'Extension' then 1 else 0 end ) as Extens
, sum ( case a.wait_event_type when 'DiskIO' then 1 else 0 end ) as DiskIO
, sum ( case a.wait_event_type when 'Client' then 1 else 0 end ) as Client
, sum ( case a.wait_event_type when 'Network' then 1 else 0 end ) as Network
from ybx_ash a

for storge, try..
select date_trunc( 'seconds' , log_dt) as dt 
, yhl.disk_usage_mb as mb 
from ybx_host_log yhl 
where host = 'node2' order by 1 ;

-- -- -- 
blog 2

To save the data to disk, we looked first at yb_ash.
There is alreay a sample_time.
We added an ID (sequence) and the nodename. 
For the nodename, we created a dedicated function to "get the name". For the moment, we use the listening-address, but if a better alternative becomes available, we'll use that.
It was complicated to find a "natual key" or a set of colums that was always unique, so we kept the ID.

yb_local_tablets is the next item to save. 
we add a node-name (host), and a capture-time.
we also have a gone-time field, that can is used to detect tablets that have move.


*/  

-- need function to get hostname, faster if SQL function ?

CREATE OR REPLACE FUNCTION ybx_get_host()
RETURNS TEXT AS $$
    SELECT setting
    FROM pg_settings
    WHERE name = 'listen_addresses';
$$ LANGUAGE sql;

/*  Drop tables
  DROP TABLE ybx_ash;
  DROP TABLE ybx_pgs_stmt;
  DROP TABLE ybx_pgs_act;
  DROP TABLE ybx_rel;
  DROP TABLE ybx_tblt;
  DROP TABLE ybx_ash_evlst;
*/

/* geneate ash reps */

\echo ybx_ash_rep and ybx_log, used for reporting

create table ybx_ash_rep (
 id           bigint        generated always as identity
, first_dt    timestamptz
, last_dt     timestamptz
, remark_txt  text
);


/* generic logging..
-- drop table ybx_log ;  
*/

create table ybx_log (
    id          bigint        generated always as identity  
  , logged_dt   timestamptz   not null
  , host        text 
  , component   text
  , ela_ms      double precision 
  , info_txt   text 
  , constraint ybx_log_pk primary key (logged_dt asc, id  asc)  
  ) ;
 
\echo ybx_ash : the main table

CREATE TABLE ybx_ash (
    id                    bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
	host                  text NULL,
	sample_time           timestamptz  NULL,
	root_request_id       uuid NULL,
	rpc_request_id        bigint default 0,
	wait_event_component  text NULL,
	wait_event_class      text NULL,
	wait_event            text NULL,
	top_level_node_id     uuid NULL,
	query_id              bigint NULL,
	ysql_session_id       int8 NULL, -- no longer needed ? 
	pid                   int8 NULL,
	client_node_ip        text NULL,
  client_addr           inet 
  client_port           integer 
	wait_event_aux        text NULL,
	sample_weight         real NULL,
	wait_event_type       text NULL,
    ysql_dbid              oid NULL
  --, constraint ybx_ash_pk primary key ( id ) 
  --, constraint ybx_ash_pk primary key ( host HASH, sample_time ASC, root_request_id ASC, rpc_request_id ASC, wait_event asc) 
) ;

create index ybx_ash_key on ybx_ash 
  ( sample_time asc, host, root_request_id, rpc_request_id, wait_event ) ; 

create index ybx_ash_host on ybx_ash 
  ( host, sample_time asc ) ; 

alter table ybx_ash add constraint 
  ybx_ash_fk_sess foreign key ( client_addr, client_port) 
      references ybx_sess_mst ( client_addr, client_port); 

\echo ybx_pgs_stmt, for pg_stat_statements. needs updates...

-- DROP TABLE ybx_pgs_stmt;

CREATE TABLE ybx_pgs_stmt (
  id                  bigint GENERATED ALWAYS AS IDENTITY, -- find pk later
  host                text not null,
  created_dt          timestamptz default now(),
	userid              oid NULL,
	dbid                oid NULL,
    toplevel            boolean NULL, -- check null
	queryid             bigint NULL,
	query               text NULL,
    plans               bigint NULL,
    total_plan_time     float8,
      min_plan_time     float8, 
      max_plan_time     float8, 
     mean_plan_time     float8, 
   stddev_plan_time     float8, 
	calls               int8 NULL,
    total_exec_time     float8,
      min_exec_time     float8,
      max_exec_time     float8,
     mean_exec_time     float8,
   stddev_exec_time     float8,
    "rows"              bigint,
	shared_blks_hit     int8 NULL,
	shared_blks_read    int8 NULL,
	shared_blks_dirtied int8 NULL,
	shared_blks_written int8 NULL,
	local_blks_hit      int8 NULL,
	local_blks_read     int8 NULL,
	local_blks_dirtied  int8 NULL,
	local_blks_written  int8 NULL,
	temp_blks_read      int8 NULL,
	temp_blks_written   int8 NULL,
	blk_read_time       float8 NULL,
	blk_write_time      float8 NULL,
    wal_records         bigint, 
    wal_fpi             bigint,
    wal_bytes           numeric,  -- supposedly large and exact
    jit_functions       bigint,
    jit_generation_time float8,
    jit_inlining_count  bigint,
    jit_inlining_time      float8,
    jit_optimization_count bigint,
    jit_optimization_time  float8,
    jit_emission_count     bigint,
    jit_emission_time      float8,
	yb_latency_histogram jsonb NULL
, constraint ybx_pgs_stmt_pk primary key  ( host, dbid, userid, queryid )
)
split into 1 tablets ;

-- store pg_stat_activity, per node + per timestamp

-- Drop table
-- DROP TABLE ybx_pgs_act;

\echo ybx_pgs_act: pg_stat_activity, almost equivalent of ps-ef

CREATE TABLE ybx_pgs_act (
  id bigint GENERATED ALWAYS AS IDENTITY, -- find pk later
  host text not null,
  sample_time timestamptz not null,
	datid           oid         NULL,
	datname         name        NULL,
	pid             int4        NULL,
    leader_pid      int4        NULL,
	usesysid        oid         NULL,
	usename         name        NULL,
	application_name text       NULL,
	client_addr     inet NULL,
	client_hostname text NULL,
	client_port     int4 NULL,
	backend_start   timestamptz NULL,
	xact_start      timestamptz NULL,
	query_start     timestamptz NULL,
	state_change    timestamptz NULL,
	wait_event_type text NULL,
	wait_event      text NULL,
	state           text NULL,
	backend_xid     xid NULL,
	backend_xmin    xid NULL,
    query_id        bigint NULL, 
	query           text NULL,
	backend_type    text NULL,
	catalog_version         int8 NULL,
	allocated_mem_bytes     int8 NULL,
	rss_mem_bytes   int8 NULL,
	yb_backend_xid uuid NULL
  -- normally, host+pid are unique, only 1 qry per pid ?
  --, constraint ybx_pgs_act_pk primary key  ( id ) 
  , constraint ybx_pgs_act_pk primary key  ( host, sample_time, pid ) 
)
split into 1 tablets ;


-- table to collect wait_events.

-- drop table ybx_evlst ; 

\echo ybx_ash_evlst: eventlist, keep track of which eventw we know-of

create table ybx_ash_evlst (
  wait_event_component    text not null
, wait_event_type         text
, wait_event_class        text
, wait_event              text not null
, found_first_host        text
, found_first_dt          timestamp
, wait_event_notes        text
, constraint ybx_ash_evlst_pk primary key ( wait_event_component asc, wait_event )
);

--- collect Table pg_class, relname, info...

/*  ****** work in progress ******** 

-- log table-size info, and only update if something changes..
-- insert if not exist..
-- upate if size_bytes or num-tablets is changed
-- gone_dt if not-found in pg_class

*/

\echo .
\echo ybx_tablog : logging data on tables, indexes...
\echo .

CREATE TABLE ybx_tablog (
  id bigint GENERATED ALWAYS AS IDENTITY primary key  -- find pk later
, logged_host       text not null                     -- just information.. 
, found_dt          timestamptz not null default now() -- signal first find
, gone_dt           timestamptz                       -- use to signal removal 
, rel_oid           oid
,	table_id          text                              -- the yb uuid
, schemaname        text                              -- names etc in case it gets dropped
, tableowner        text
, relname           text
, relkind           text
, size_bytes        bigint
, num_tablets       bigint
, num_hash_key_columns bigint
)
split into 1 tablets ;

create index ybx_tablog_oid on ybx_tablog ( rel_oid, found_dt ) split into 1 tablets ;
create index ybx_tablog_dt  on ybx_tablog ( found_dt asc ) ; 

-- create index ybx_tablog_all on ybx_tablog ( rel_oid, size_bytes, num_tablets, num_hash_key_columns ) ; 
/* ***** */


/* *****************************************************************/

\echo ybx_tblt:  table to collect tablet info...

-- DROP TABLE ybx_tblt;

CREATE TABLE ybx_tblt (
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

-- collect events, using functions

\echo .
\echo mk_ybash.sql: now the funcitons --------------------- 

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
  n_ashrecs     bigint            := 0 ; 
  n_stmnts      bigint            := 0 ; 
  n_actvty      bigint            := 0 ; 
  retval        bigint            := 0 ;
  start_dt      timestamp         := clock_timestamp();
  end_dt        timestamp         := now() ;
  duration_ms   double precision  := 0.0 ;
  cmmnt_txt      text              := 'comment ' ;
BEGIN

-- ash-records, much faster using with clause ?
with /* get_ash_1 */ 
  h as ( select ybx_get_host () as host )
-- , l as ( select al.* from ybx_ash al 
--              where al.host = ybx_get_host()
--                and al.sample_time > (now() - interval '900 sec' ) )
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
, pid
, client_node_ip 
, wait_event_aux
, sample_weight 
, wait_event_type 
, ysql_dbid
)
select 
  h.host as host
, a.sample_time  
, a.root_request_id  
, coalesce ( a.rpc_request_id, 0 )  as rpc_id
, a.wait_event_component 
, a.wait_event_class 
, a.wait_event 
, a.top_level_node_id 
, a.query_id 
, 0 -- a.ysql_session_id  -- find related info
, a.pid
, a.client_node_ip 
, a.wait_event_aux
, a.sample_weight 
, a.wait_event_type 
, a.ysql_dbid
from yb_active_session_history a , h h
where not exists ( select 'x' from ybx_ash b 
                   where b.host            = h.host 
                   and   b.sample_time     = a.sample_time
                   and   b.root_request_id = a.root_request_id
                   and   b.rpc_request_id  = coalesce ( a.rpc_request_id, 0 )
                   and   b.wait_event      = a.wait_event
                   -- and   b.sample_time > ( start_dt - make_interval ( secs=>900 ) )
                 );

GET DIAGNOSTICS n_ashrecs := ROW_COUNT;
retval := retval + n_ashrecs ;

RAISE NOTICE 'ybx_get_ash() yb_act_sess_hist : % ' , n_ashrecs ; 

-- now collect pg_stat_stmnts (and activity )
-- note: explain causes duplicte queryids... 
with /* get_ash_2_stmt */ h as ( select ybx_get_host () as host )
insert into ybx_pgs_stmt ( 
  host ,   -- check if qryid is same on host
	userid , 
	dbid , 
    toplevel ,
	queryid , 
	query , 
    plans ,
    total_plan_time ,
      min_plan_time ,
      max_plan_time, 
     mean_plan_time ,
   stddev_plan_time ,
	calls , 
	total_exec_time ,
  	  min_exec_time  ,
	  max_exec_time  ,
	 mean_exec_time ,
   stddev_exec_time  ,
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
    wal_records ,
    wal_fpi ,
    wal_bytes ,
    jit_functions ,
    jit_generation_time ,
    jit_inlining_count ,
    jit_inlining_time ,
    jit_optimization_count ,
    jit_optimization_time ,
    jit_emission_count ,
    jit_emission_time ,
	yb_latency_histogram 
)
select 
  h.host,
	userid , 
	dbid , 
    toplevel ,
	queryid , 
	query , 
    plans ,
    total_plan_time ,
    min_plan_time ,
    max_plan_time, 
    mean_plan_time ,
    stddev_plan_time ,
	calls , 
	total_exec_time ,
  	  min_exec_time  ,
	  max_exec_time  ,
	 mean_exec_time ,
   stddev_exec_time  ,
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
    wal_records ,
    wal_fpi ,
    wal_bytes ,
    jit_functions ,
    jit_generation_time ,
    jit_inlining_count ,
    jit_inlining_time ,
    jit_optimization_count ,
    jit_optimization_time ,
    jit_emission_count ,
    jit_emission_time ,
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
and lower ( substring ( s.query from 1 for 8 )) != 'explain ' 
;

GET DIAGNOSTICS n_stmnts := ROW_COUNT;
retval := retval + n_stmnts ;
RAISE NOTICE 'ybx_get_ash() pg_stat_stmnts   : % ' , n_stmnts ; 

-- collect acitivity..

with /* get_ash_3_act */ h as ( select ybx_get_host () as host, now() as smpltm )
insert into ybx_pgs_act (
  host ,
  sample_time ,
  datid ,
  datname ,
  pid ,
  leader_pid , 
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
  query_id ,
  query ,
  backend_type ,
  catalog_version ,
  allocated_mem_bytes ,
  rss_mem_bytes ,
  yb_backend_xid 
)
select 
  h.host, 
  h.smpltm,
  datid ,
  datname ,
  pid ,
  leader_pid , 
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
  query_id ,
  query ,
  backend_type ,
  catalog_version ,
  allocated_mem_bytes ,
  rss_mem_bytes ,
  yb_backend_xid
from pg_stat_activity a, h h ;
-- no where clause at all ?

GET DIAGNOSTICS n_actvty := ROW_COUNT;
retval := retval + n_actvty ;
RAISE NOTICE 'ybx_get_ash() pg_stat_activity : % ' , n_actvty ; 
    
duration_ms := EXTRACT ( MILLISECONDS from ( clock_timestamp() - start_dt ) ) ; 

RAISE NOTICE 'ybx_get_ash() elapsed : % ms'     , duration_ms ; 

cmmnt_txt := 'ash: ' || n_ashrecs || ', stmnts: ' || n_stmnts || ', actvty: ' || n_actvty || '.'; 

insert into ybx_log ( logged_dt, host,       component,     ela_ms,      info_txt )
       select clock_timestamp(), ybx_get_host(), 'ybx_get_ash', duration_ms, cmmnt_txt ; 

-- end of fucntion..
return retval ;

END; -- ybx_get_ash, to incrementally populate table
$$
;


/*

function : ybx_get_tblts();

collect ybx_tblt with local tablets, local to current node
returns total nr of records inserted and updated

todo: how to spot tablets from nodes that have dissapeared... ? 

*/

CREATE OR REPLACE FUNCTION ybx_get_tblts()
  RETURNS bigint
  LANGUAGE plpgsql
AS $$
DECLARE
  nr_rec_processed bigint         := 0 ;
  n_created     bigint            := 0 ;
  n_gone        bigint            := 0 ;
  start_dt      timestamp         := clock_timestamp();
  end_dt        timestamp         := now() ;
  duration_ms   double precision  := 0.0 ;
  retval        bigint            := 0 ;
  cmmnt_txt     text              := ' ' ;
BEGIN

-- insert any new-found tablets on this node...
with /* get_tblts_1 */ 
  h as ( select ybx_get_host () as host )
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
  start_dt,
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

GET DIAGNOSTICS n_created := ROW_COUNT;
retval := retval + n_created ;
RAISE NOTICE 'ybx_get_tblts() created : % tblts' , n_created ; 

-- update the gone_date if tablet no longer present..
-- signal gone_date if ... gone
with /* get_tblts_2 */ 
  h as ( select ybx_get_host () as host )
update ybx_tblt t set gone_time = start_dt 
where 1=1 
and   t.gone_time  is null                   -- no end time yet
and   t.host       in ( select host from h ) -- same host
and not exists (                             -- no more local tblt
  select 'x' from yb_local_tablets l
  where   t.tablet_id  =  l.tablet_id 
  )
;

GET DIAGNOSTICS n_gone := ROW_COUNT;
retval := retval + n_gone ;

duration_ms := EXTRACT ( MILLISECONDS from ( clock_timestamp() - start_dt ) ) ; 

RAISE NOTICE 'ybx_get_tblts() gone    : % tblts'  , n_gone ; 
RAISE NOTICE 'ybx_get_tblts() elapsed : % ms'     , duration_ms ; 

cmmnt_txt := 'created: ' || n_created || ', gone: ' || n_gone || '.' ;

insert into ybx_log ( logged_dt, host,       component,     ela_ms,      info_txt )
       select clock_timestamp(), ybx_get_host(), 'ybx_get_tblts', duration_ms, cmmnt_txt ; 

  -- end of fucntion..
  return retval ;

END; -- function ybx_get_tblts: to get_tablets
$$
;

/* ***************************************

function : ybx_get_tablog();

collect ybx_tablog to check sizes and nr tablets
returns total nr of records inserted and updated

todo: check.. 

*/

CREATE OR REPLACE FUNCTION ybx_get_tablog()
  RETURNS bigint
  LANGUAGE plpgsql
AS $$
DECLARE
  nr_rec_processed bigint         := 0 ;
  n_created     bigint            := 0 ;
  n_updated     bigint            := 0 ;
  n_gone        bigint            := 0 ;
  start_dt      timestamp         := clock_timestamp();
  end_dt        timestamp         := now() ;
  duration_ms   double precision  := 0.0 ;
  retval        bigint            := 0 ;
  cmmnt_txt     text              := ' ' ;
BEGIN

-- insert any new-found tables on this node...
-- also: insert new record if properties have changed..
-- better: use tabl_mst + tabl_log ... later
with /* tablog_1 */ h as ( select ybx_get_host () as host )
insert into ybx_tablog (
  logged_host ,
  rel_oid , 
  table_id , 
  schemaname ,
  tableowner ,
  relname ,
  relkind ,
  num_tablets ,
  num_hash_key_columns ,
  size_bytes 
)
select
  h.host  ,
  t.oid   ,
  t.table_id ,
  t.schemaname ,
  t.tableowner ,
  t.relname ,
  t.relkind ,
  t.num_tablets ,
  t.num_hash_key_columns ,
  t.size_bytes
  FROM ybx_tblinfo t, h
  where 1=1
  and t.size_bytes is not null
  and t.num_hash_key_columns is not null
  and t.num_tablets is not null 
  and not exists 
      ( select 'x' from ybx_tablog l
        where 1=1
          and t.oid                   =  l.rel_oid   -- assume oid is the identifying item
          and t.size_bytes            = l.size_bytes -- only if nothing changed
          and t.num_tablets           = l.num_tablets
          and t.num_hash_key_columns  = l.num_hash_key_columns
      ) ;

GET DIAGNOSTICS n_created := ROW_COUNT;
retval := retval + n_created ;
RAISE NOTICE 'ybx_get_tablog() created : % tablogs' , n_created ; 

-- update the gone_date if tablet no longer present..

-- signal gone_date if ... gone
with /* tablog_2 */ h as ( select ybx_get_host () as host )
update ybx_tablog t set gone_dt = start_dt 
where 1=1 
and t.gone_dt  is null                   -- no end time yet
and not exists (                         -- no more class
  select 'x' from pg_class c
  where   c.oid  =  t.rel_oid 
  )
;

GET DIAGNOSTICS n_gone := ROW_COUNT;
retval := retval + n_gone ;

duration_ms := EXTRACT ( MILLISECONDS from ( clock_timestamp() - start_dt ) ) ; 

RAISE NOTICE 'ybx_get_tablog() gone    : % tabs'  , n_gone ; 
RAISE NOTICE 'ybx_get_tablog() elapsed : % ms'     , duration_ms ; 

cmmnt_txt := 'created: ' || n_created || ', gone: ' || n_gone || '.' ;

insert into ybx_log ( logged_dt, host,            component,       ela_ms,      info_txt )
       select clock_timestamp(), ybx_get_host(), 'ybx_get_tablog', duration_ms, cmmnt_txt ; 

  -- end of fucntion..
  return retval ;

END; -- function ybx_get_tablog: to log table-size and num_tablets
$$
;

/* *****************************************************************

function : ybx_get_evlst();

collect all possible wait_event names (name + component)
returns total nr of records added

by running this function regularly, we hope to spot all events

*/

CREATE OR REPLACE FUNCTION ybx_get_evlst()
  RETURNS bigint
  LANGUAGE plpgsql
AS $$
DECLARE
  start_dt      timestamp         := clock_timestamp(); 
  end_dt        timestamp         := now() ;
  hostnm        text              := ybx_get_host() ;
  duration_ms   double precision  := 0.0 ;
  nr_rec_processed bigint         := 0 ;
  retval        bigint            := 0 ;
  cmmnt_txt     text              := 'Event found ' ;
BEGIN

cmmnt_txt := 'first found on node: ' || hostnm 
                 || ', at: ' || start_dt::text ;

/*
with l as (
  select distinct 
    wait_event_component
  , wait_event_type
  , wait_event_class
  , wait_event
  , hostnm         as found_first_host
  , start_dt       as found_first_dt
  , comment_txt as add_comment_txt
  from yb_active_session_history 
)
*/ 

insert into ybx_ash_evlst  
select distinct 
      wait_event_component
    , wait_event_type
    , wait_event_class
    , wait_event
    , hostnm
    , start_dt
    , cmmnt_txt
from yb_active_session_history l
where not exists ( select 'xzy' as xyz from ybx_ash_evlst f
                    where l.wait_event_component = f.wait_event_component
                    and   l.wait_event           = f.wait_event
);
  
GET DIAGNOSTICS nr_rec_processed := ROW_COUNT;
retval := retval + nr_rec_processed ;
    
duration_ms := EXTRACT ( MILLISECONDS from ( clock_timestamp() - start_dt ) ) ;
  
RAISE NOTICE 'ybx_get_evlst() elapsed : % ms'     , duration_ms ;

cmmnt_txt := 'created: ' || nr_rec_processed || '.' ;

insert into ybx_log ( logged_dt, host,       component,            ela_ms,      info_txt )
       select clock_timestamp(), ybx_get_host(), 'ybx_get_evlst', duration_ms, cmmnt_txt ;

-- end of fucntion..
return retval ;

END; -- get_evlst, to incrementally populate table
$$
; 

-- test function right away
select (select count (*) evlst from ybx_ash_evlst  ) evlst ;

select ybx_get_evlst() ; 

select (select count (*) evlst from ybx_ash_evlst  ) evlst ;

-- -- -- -- -- -- -- --
-- function to test cron, included here bcse cront would help collect ash
-- will sleep for x seconds, dflt 1

CREATE OR REPLACE FUNCTION ybx_testcron( )
  RETURNS bigint
  LANGUAGE plpgsql
AS $$
DECLARE
  start_dt      timestamp         := clock_timestamp(); 
  end_dt        timestamp         := now() ;
  hostnm        text              := ybx_get_host() ;
  duration_ms   double precision  := 0.0 ;
  nr_rec_processed bigint         := 0 ;
  retval        bigint            := 0 ;
  cmmnt_txt     text              := 'Event found ' ;
BEGIN

cmmnt_txt := 'testing cron on: ' || hostnm 
                 || ', at: ' || start_dt::text ;

-- select pg_sleep ( 1 ) into retval ; 

duration_ms := EXTRACT ( MILLISECONDS from ( clock_timestamp() - start_dt ) ) ;

insert into ybx_log ( logged_dt, host,   component,      ela_ms,      info_txt )
       select clock_timestamp(), hostnm, 'ybx_testcron', duration_ms, cmmnt_txt ;

-- end of fucntion..
return retval ;

END; -- ybx_testcron, to incrementally populate table
$$
; 

-- check 2 sec, find results in ybx_log
select ybx_testcron ( ) as testcron ;

-- schedule a test job..
select cron.schedule ('*/3 * * * *', $$ select ybx_testcron(); $$) 
where not exists ( select 'x' from cron.job j where j.command like '%ybx_testcron%' );

-- schedule the logging of tab-sizes
select cron.schedule ('*/4 * * * *', $$ select ybx_get_tablog(); $$) 
where not exists ( select 'x' from cron.job j where j.command like '%ybx_get_tablog%' );

-- call functions and compare counts to test

select 
  (select count (*) ash   from ybx_ash        ) ash
, (select count (*) stmts from ybx_pgs_stmt   ) stmts
, (select count (*) activ from ybx_pgs_act    ) activ 
, (select count (*) evlst from ybx_ash_evlst  ) evlst ;
 
select ybx_get_ash () collect_function_called; 

select 
  (select count (*) ash   from ybx_ash        ) ash
, (select count (*) stmts from ybx_pgs_stmt   ) stmts
, (select count (*) activ from ybx_pgs_act    ) activ 
, (select count (*) activ from ybx_ash_evlst  ) evlst ;
 
-- and tablets..
select count (*) tablets_detected, host from ybx_tblt group by host ;

select ybx_get_tblts () as nr_tablets_processed ;

select count (*) tablets_detected, host from ybx_tblt group by host ;

select ybx_get_tablog() tablogs;

