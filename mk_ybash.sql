/*

file: mk_ybash.sql: functions and tables for yb_ash and pg_stat data.
 - choose to store first + on every node, 
   we take  insert- and select-rpc overhead..
 - useing sql-funciton for detecting hostname

usage:
 - prepare for ash-usage, include yb_flags, check blogs.
 - verify the view yb_active_session_history is present
 - run script \i mk_ybash.sql: to create functions + tables, 
   check for erros in case DDL changes
 - test using do_ybash.sql : can all nodes collect data ?
 - schedule for regular collection, e.g. 1min, 10min.: do_ashloop.sh
 - optional: check to have yb_init.sql done, reate helper-functions (cnt)
 - optional: add \i mk_ashvws.sql for the gv views from Frankc.

todo, high level.
 - blog: save data in tables, then qry if needed.. only pick most recent data from mem.
   - add code + examples, notably interval
 - test with masters on separate nodes, see where activity goes.
    sar shows equal activity, but top shows activ only on nodes with tablets..
 - grafana: use qries with time (minute) and metrics.. 
 - grafana: use qries with count per stmnt (over last x min), and display top stmnt.
 - reports: find top-consumers
 - reports: zoom in, tree, or hierarchy.. despite yb-claim..
 - report + data: why sometimes 25K reords per minute?? what kind of events?
 - try logging "sessions" from client_node_ip: create_dt and gone_dt, or sess_id
 - link ahs to activity, qry-text not the same, with/out $n substitutes
 - link ash to pg_stat_statements with query_id
 - save pg_stat_stmt + metrics (2 tables: stmnt_id, and id+metrics_in_interval)
 - detect tablets that have moved, try finding "where to" or "where from"
 - detect tablets on non-existing nodes.. close them..  (gone_time, closed by self or other...)? 

todo:
 - num tablets : select * from yb_table_properties(16642 ) is wrong.., 
    it relects nr tablest on startup of the tserver try this with auto-split, and see.
 - invalid byte sequence: some type conversion in get_ash ?
 - at some points, inserts of 10K records.. Why ??
 - check TEST_ash flag.. try out ?
 - check load of metrics-curling.. http://localhost:9004/prometheus-metrics
 - spot ClientRead as passive status ?  : no proof.. forget it for now
 - test on colocated db: only 1 tablet, and 1 table-name. complicated..?  hmm
 - unique key, still duplicates in ash: wait-event-aux is sometimes only distinquiser..
   revert to id as key !
 - speed up insertions into logtables with indexes, host+ sample_time
 - types: tservers().uuid is txt, top-level is uuid.. mix of types
 - pg_stat_statement: needs re-think. for exmpl, save every "interval" and reset
 - pg_stat_statement; could use a timestamp of "date-time found"
 - pg_stat_statement: consider merge with new stats every 10min ? 
 - split get_ash() in  3 : ash, pg_stat_statments, and pg_stat_activity
 - Q: how to relate queryid to pg_stat_activity, ask for enhancement ?
 - Q: how to relate sessionid to pid ? 
 - Q: Mechanism to run SQL on every node ? Scheduler? 
 - keep list of servers, detect when server is down? - scrape from ybadmin?
 - keep list of masters (how? needs ybtool or yb-admin ? and copy-stdout)
 - store class-oid with tablets 
 - Q: detect migrated + dropped tablets, and dissapeared nodes. how ???
 - use dflts for host and timestamp in DDL?
 - Q: should we introcude a snap_id (snapshot) 
   to link related data to 1 event or 1 point-in-time ?
 - need a repeatable "load generator", notaby IO-write and IO-read.
    mk_longt.sql? 
 - script: wheris.sql: tablet or table, and list the nodes where it is/was.
 - script: yb_ash_int.sql: generate report for interval, define in top of file
 - script: yb_ash_topsql.sql: list most found SQL., per count, per mem, per rows, per calls.
 - t_long2.: insert a lot of data, generate long tx, long sql.
 - collect mem per snapshot: sum (pg_stat_act)
 - use count + interval of 'OnCpu_Passive' to find cpu-saturation? 

todo on tablets: improve monitoring and logic
 - yb_local_tablets, to Separate SCript, and detect down-nodes/moved tblts
 - yb_local_tablets: state=ok,suspect,gone, depending on node and last-seen?
 - store class-oid of table with tablets (why? not urgen?)
 - find Master-tserver (node or uuid) for tablet, how?

more todo
 - get 1 benchmark, and test.., need tables of 2G or more to really hammer..
 - standardize test-results: use script to report on cutoff-interval 
 - compare with mapped volumes and local-docker volumes
 - compare with more docker-resources: more cpus: not a success.
 - compare with smaller interval, say 100ms: not on mac-docker, cpu loaded..
 - test with fresh-start cluster: clean memory ? 
 - test with 1 or more nodes down + up. watch redistribution ?
 - Idle, ClientRead etc: make a list of Idle events
 - log yb-admin masters and tservers

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

select /* Graph01: w_ev_class * /  date_trunc( 'seconds' , sample_time) as dt 
, sum ( case a.wait_event_class when 'YSQLQuery' then 1 else 0 end ) as YQry
, sum ( case a.wait_event_class when 'Common' then 1 else 0 end ) as Common
, sum ( case a.wait_event_class when 'TServerWait' then 1 else 0 end ) as TServer
, sum ( case a.wait_event_class when 'TabletWait' then 1 else 0 end ) as TabletWait
, sum ( case a.wait_event_class when 'Consensus' then 1 else 0 end ) as Consensus
, sum ( case a.wait_event_class when 'Client' then 1 else 0 end ) as Cliet
, sum ( case a.wait_event_class when 'RocksDB' then 1 else 0 end ) as RocksDB
from ybx_ash a
group by 1 

select /* Graph01: w_ev_Type * / date_trunc( 'seconds' , sample_time) as dt 
, sum ( case a.wait_event_type when 'Cpu' then 1 else 0 end ) as CPU
, sum ( case a.wait_event_type when 'WaitOnCondition' then 1 else 0 end ) as WonCond
, sum ( case a.wait_event_type when 'Extension' then 1 else 0 end ) as Extens
, sum ( case a.wait_event_type when 'DiskIO' then 1 else 0 end ) as DiskIO
, sum ( case a.wait_event_type when 'Client' then 1 else 0 end ) as Client
, sum ( case a.wait_event_type when 'Network' then 1 else 0 end ) as Network
from ybx_ash a

blog -- -- - -

title: logging performance-information in a distributed database.

TL;DR: I choose to store the ASH data in tables, whereby every node logs its own data. To see the data, I query the tables with SQL.
I tried to minimize additional inter-host communication, and avoid additional mechanisms like FDW or dedicated RPCs, while storing the data for possible later usage.
The main disadvantages are... 
1) There is insert activity, 
2) Data is only available after insert-into-table, and thus depends on a sampling interval 
and 3) There is incomplete logging when components in the postgres-layer get broken. 

Background:
I'm using Yugabyte, a distributed database, and I try to keep track the workload-history if you like, of the system. 
PG and YB make some internal data available via views : pg_stat_statements, pg_stat_activity, yb_active_session_history and yb_local_tablets. 
This data can help you find bottlenecks and hotspots in your system. 

You can find the (first version of) ASH documentatin here:
https://docs.yugabyte.com/preview/explore/observability/active-session-history/

... move txt down a bit ...
Franck Pachot then used the FDW and a Union-All to put the data in a single, unified view, which is explained and demonstrated here:
https://dev.to/yugabyte/active-session-history-ash-in-yugabytedb-39ic

Followed by a very cool visualization using grafana here:
https://dev.to/yugabyte/find-hotspots-with-yugabyte-active-session-history-45db

This data, and the concepts used by Franck will help you find bottlenecks and hotspots in your system.  I suspect other can build on his ideas to create all sorts of cool diagnostics tools.

Now I also wanted to keep that ASH data for later analysis, so I could look back at Yesterday's problem, even though the buffers would not keep data that old, or even my servers might have been cycled.



Per node data, needs to be unified.

Yugabyte is a distributed database but the information from the views, active_session_history and pg_stats, is still "local" to each node, e.g. a node only sees and reports on its own status.

To have a cluster-wide view, you need to query this data on every node, and somehow combine it.

Franck solved that by using a Foreign-Data-Wrapper (FDW) to select the views from all remote nodes, and by doing a union-all on them. His gv$yb_active_session_history "fetches" all the data from all the nodes every time the view is queried. This also, currently, means the union-view becomes unusable when a node (part of the union-data in the view) is unresponsive or down.

In this post I want to outline an alternative, where I try keep nodes working independently and only unite the data when needed, when I query it from the Table where I store it. 

There are pros and cons to each approach.


Storing data to Table, readably by any session.

Instead of using FDW to query other nodes, I let each node store its own data.
I insert the data from yb_active_session_history into a table, and add the host-name (node-name, server name, whichever is listed as host in select * from yb_servers() ;
Sessions on other hosts will be able to see the data after commit, and it only needs the (postgres) SQL-interface to access the data.

There are three other views for which I save the contents, the data of which I need later to join to the collectd ASH data: 
yb_local_tablets
pg_stat_statements
pg_stat_activity.
Each of these warrants a discussion on its own but that is out of scope now. I may come back to this in a later post, but first let me describe the concept in more detail.


To capture the data, I created functions that insert the data from these views into (postgres)tables, and I make sure to skip existing data to prevent doubles. From the moment the data is inserted it is Readable by any connection with access to the tables.

The interval with which data is logged is important, as it determines the timeliness, e.g. how fast the ASH-data becomes available to anyone who queries the tables. A short interval will cause some overhead, a long interal will hamper instant-diagnosis as we need to wait for data to get captured. I found an interval of 60 or 180 seconds to be manageable, but YMMV.

I've constructed loop-shell scripts to do the capturing which can be run on each of the nodes. so far, each of the capture-functions runs in under 1 second, and doesnt seem to cause much overhead or hiccups.


Pros and Cons.

pro: Simple, existing tools.
The big advantage (nr 1) I see is that there is no need for FDW and no mappings or imports of remote objects. 

pro: Creation of a History.
The other advantage (nr 2) is that the data is saved and kept over longer periods of time, and over server-reboots. This allows for post-mortem inspection of problems.

pro: Robust execution, local to each node.
The logging will not be affected by node-out, not even by temporary network-failings, as there is no connecting- or other dependency on other nodes in the cluster.. The logging will not be affected by node-out from peer-nodes, as there is no connecting- or other dependency on other nodes in the cluster.

Note: at some point, I may also consider the monitoring/logging of node-connectivity, or node-outages. But that is out of scope for the moment.


con: Insert is needed before the data is visible, and thus we create additional table-insert activity. I have not tested this yet on significantly large machines or highly active machines.

con: Need to wait for the insert to happen, The data in the views is instantly visible on the nodes. But in the worst case, the table-data needs to wait for the sample-interval before it can be seen.

con: Depends on the full-stack of a mostly functional YB-database: It needs the postgres layer to run the inserts, and the TSever to process the data before it is visible or usable by others.


Concluding remarks:

I will try to create a repository with readable and usable demo-code (link when available) and I'm open to discussion of the topic and to examine pros and cons.

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
  DROP TABLE ybx_tblt;
  DROP TABLE ybx_ash_evlst;
*/

/* geneate ash reps */

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
 

CREATE TABLE ybx_ash (
  id                    bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
	host                  text NULL,
	sample_time           timestamptz  NULL,
	root_request_id       uuid NULL,
	rpc_request_id        int8 default 0,
	wait_event_component  text NULL,
	wait_event_class      text NULL,
	wait_event            text NULL,
	top_level_node_id     uuid NULL,
	query_id              int8 NULL,
	ysql_session_id       int8 NULL,
	client_node_ip        text NULL,
	wait_event_aux        text NULL,
	sample_weight         float4 NULL,
	wait_event_type       text NULL
  --, constraint ybx_ash_pk primary key ( id ) 
  --, constraint ybx_ash_pk primary key ( host HASH, sample_time ASC, root_request_id ASC, rpc_request_id ASC, wait_event asc) 
) 
split into 1 tablets
;

create index ybx_ash_key on ybx_ash 
  ( sample_time asc, host, root_request_id, rpc_request_id, wait_event ) ; 

create index ybx_ash_host on ybx_ash 
  ( host, sample_time asc ) ; 


-- DROP TABLE ybx_pgs_stmt;

CREATE TABLE ybx_pgs_stmt (
  id                  bigint GENERATED ALWAYS AS IDENTITY, -- find pk later
  host                text not null,
  created_dt          timestamptz default now(),
	userid              oid NULL,
	dbid                oid NULL,
	queryid             int8 NULL,
	query               text NULL,
	calls               int8 NULL,
	total_time          float8 NULL,
	min_time            float8 NULL,
	max_time            float8 NULL,
	mean_time           float8 NULL,
	stddev_time         float8 NULL,
	"rows"              int8 NULL,
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
	yb_latency_histogram jsonb NULL
, constraint ybx_pgs_stmt_pk primary key  ( host, dbid, userid, queryid )
)
split into 1 tablets ;

-- store pg_stat_activity, per node + per timestamp

-- Drop table
-- DROP TABLE ybx_pgs_act;

CREATE TABLE ybx_pgs_act (
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


-- table to collect wait_events.

-- drop table ybx_evlst ; 

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


-- table to collect tablet info...

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
with h as ( select ybx_get_host () as host ) 
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
, coalesce ( a.rpc_request_id, 0 )  as rpc_id
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
                   -- and   b.sample_time > ( start_dt - make_interval ( secs=>900 ) )
                 );

GET DIAGNOSTICS n_ashrecs := ROW_COUNT;
retval := retval + n_ashrecs ;

RAISE NOTICE 'ybx_get_ash() yb_act_sess_hist : % ' , n_ashrecs ; 

-- now collect pg_stat_stmnts (and activity )
with h as ( select ybx_get_host () as host )
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

GET DIAGNOSTICS n_stmnts := ROW_COUNT;
retval := retval + n_stmnts ;
RAISE NOTICE 'ybx_get_ash() pg_stat_stmnts   : % ' , n_stmnts ; 

-- collect acitivity..

with h as ( select ybx_get_host () as host, now() as smpltm )
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
  h.smpltm,
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
with h as ( select ybx_get_host () as host )
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
with h as ( select ybx_get_host () as host )
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

