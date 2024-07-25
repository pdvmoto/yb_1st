
\set n_sec 1800.0

/*

file : yb_ashrep: report the top-events from ash.

notes:
 - it is a SAMPLE.. not a stopwatch-timer.

dependencies:
 - mk_ybash.sql: create supporting objects, run on 1 node
 - mk_ashvws.sql: create gv$ (from Franck), run on 1 node

todo, reporting...
 - qry events from last 900 sec.. live. regardless of recording. LEARN
 - generate function to create report - from tbls.
 - Fix-Interval, bcse time window sliding due to slow queries
 - Investigea: some intervals have 20-K records per Minute.. ???? 

todo:
 - think of graphic visual, how to display...
 - get meaning of wait-events.
 - capacity : list of "idle" events, e.g. not consuming thread or cpu on server
 - network: how to measure ?
 - add top-request, + link to SQL
 - top-event per interval, per minute if possible..

*/

/* --- find activity ---

SELECT pa.query, pa.state , pa.*  
FROM gv$pg_stat_activity pa  
where 1=1 
--and state = 'active' 
and query not like 'FETCH 100 FROM c1'
order by state 
 ;

----- */

\! clear 

select 'ash from memory contents, local and global' as ashrep_check ; 

select ybx_get_host() running_ahsrepn 
, :n_sec secs_interval
, to_char ( now()  - make_interval ( secs=> :n_sec ), 'YYYY-DD-MM HH24:MI:SS' ) in_between
, to_char ( now(), 'YYYY-DD-MM HH24:MI:SS' ) and_now
;

select host current_host, uuid 
from yb_servers () tsrv_uuid where public_ip in ( select ybx_get_host() ) ;

select  count (*) local_samples
      , to_char ( min (sample_time), 'YYYY-MM-DD HH24:MI:SS' ) oldest_in_buff
      , to_char ( max (sample_time), 'YYYY-MM-DD HH24:MI:SS' ) latest_in_buff
      , ybx_get_host() local_host
from yb_active_session_history ;

select count (*) gv_samples
      , to_char ( min (sample_time), 'YYYY-MM-DD HH24:MI:SS' ) oldest_in_gv_buff
      , to_char ( max (sample_time), 'YYYY-MM-DD HH24:MI:SS' ) latest_in_gv_buff
      , gv$host  host
from gv$yb_active_session_history 
group by gv$host
order by gv$host;

\echo .
\! read -t 10 -p "1. above: check if any data present in local and gv views... " abc
\echo .
\echo .

select 'ash data stored in DB, global on all nodes... ' as second_check ; 

\timing on

/*** 
select  count (*) nr_records
      , to_char ( min (sample_time), 'YYYY-MM-DD HH24:MI:SS' ) oldest_stored
      , to_char ( max (sample_time), 'YYYY-MM-DD HH24:MI:SS' ) latest_stored
      , ( max (sample_time)  -  min (sample_time) ) as interval_stored
from ybx_ash ;
****/

select
   count (*) recs_per_node
, to_char ( min (sample_time), 'YYYY-MM-DD HH24:MI:SS' ) oldest_stored
, to_char ( max (sample_time), 'YYYY-MM-DD HH24:MI:SS' ) latest_stored
, to_char (  age ( now (), max(sample_time) ), 'ssss' )  secs_ago
, host
from ybx_ash 
group by host
order by host ;

\timing off

\echo .
\! read -t 10 -p "2. above: check total data stored, per hosts... " abc
\echo .
\echo .
--\! sleep 2


\timing on

-- busiest nodes in sample
with cutoff as ( select now() - make_interval (secs => :n_sec )  as sincedt ) 
select
   count (*)                                             recs_in_intrv
, to_char ( min (sample_time), 'YYYY-MM-DD HH24:MI:SS' ) oldest_stored
, to_char ( max (sample_time), 'YYYY-MM-DD HH24:MI:SS' ) latest_stored
, to_char (  age ( now (), max(sample_time) ), 'ssss' )  secs_ago
, a.host
from ybx_ash a, cutoff c
where sample_time > c.sincedt
group by a.host
order by a.host ;


/* **** 
-- check current_node via view...
with cutoff as  
(  select now() - make_interval (secs => :n_sec) as sincedt
, ybx_get_host() as host 
) 
select count (*) cnt
, sincedt
, host as busiest_ash
from yb_active_session_history ya
   , cutoff c 
where ya.sample_time > c.sincedt
group by sincedt, sincedt, host 
order by 1 desc 
limit 10;
*****  */ 

-- busiest events component 

with cutoff as  
(  select now() - make_interval (secs => :n_sec) as sincedt
, ybx_get_host() as host 
) 
select  
        count (*)             cnt
      , wait_event_component  busiest_comp 
--, host
from ybx_ash ya
   , cutoff c 
where ya.sample_time > c.sincedt
group by wait_event_component -- , c.host
order by 1 desc  
;

-- add component + class..., e.g. does Tserver use CPU
with cutoff as  
(  select now() - make_interval (secs => :n_sec) as sincedt
, ybx_get_host() as host 
) 
select  
        count (*)             cnt
      , wait_event_component  busiest_comp 
      , wait_event_class      
--, host
from ybx_ash ya
   , cutoff c 
where ya.sample_time > c.sincedt
group by wait_event_component , wait_event_class -- , c.host
order by 1 desc  
;

with cutoff as  
(  select now() - make_interval (secs => :n_sec) as sincedt
, ybx_get_host() as host 
) 
select  
        count (*)             cnt
      , ya.host
      , wait_event_component  busiest_comp 
      , wait_event_class      
      , count (*)             cnt
--, host
from ybx_ash ya
   , cutoff c 
where ya.sample_time > c.sincedt
group by ya.host, ya.wait_event_component , ya.wait_event_class -- , c.host
order by 1 desc, 2
;

with cutoff as  
(  select now() - make_interval (secs => :n_sec) as sincedt
, ybx_get_host() as host 
) 
select   
          count (*)             cnt
        , wait_event_component  per_comp 
        , ya.host               hostname
from ybx_ash ya
   , cutoff c 
where ya.sample_time > c.sincedt
group by 2, 3
order by wait_event_component, 1 desc , ya.host  
limit 30;

with cutoff as  
(  select now() - make_interval (secs => :n_sec) as sincedt
, ybx_get_host() as host 
) 
select    
          count (*)                 cnt
        , ya.host                   per_host
        , ya.wait_event_component   busiest_comp 
from ybx_ash ya
   , cutoff c
where ya.sample_time >  c.sincedt
group by ya.wait_event_component, ya.host
order by 2, 1 desc
limit 30;

\echo .
\! read -t 10 -p "3. above: top-component per hosts, in what layer... " abc
\echo .
\echo .

with cutoff as  
(  select now() - make_interval (secs => :n_sec) as sincedt
, ybx_get_host() as host 
) 
select  count (*)         cnt
      , ya.host           per_host
      , wait_event_class  busiest_class
from ybx_ash ya
   , cutoff c 
where ya.sample_time > c.sincedt
group by wait_event_class, ya.host
order by 1 desc, 2
limit 30;

\echo .
\! read -t 10 -p "3.1. above: top-class per hosts... " abc
\echo .
\echo .

\echo .
\! read -t 10 -p "4. below: top-ev_type per hosts... " abc
\echo .
\echo .

-- busiest events, type
-- with cutoff as ( select now() - make_interval ( secs=> :n_sec ) as sincedt ) 

select  count (*)   cnt
      , ya.host     per_host
      ,             wait_event_type
from ybx_ash ya
where 1=1 -- ya.sample_time > c.sincedt
and   sample_time > ( now() - make_interval ( secs=> :n_sec )  )
group by wait_event_type, ya.host
order by 1 desc, 2
limit 30;

-- busiest events
with cutoff as ( select now() - make_interval ( secs=>:n_sec ) as sincedt ) 
select count (*) cnt
    , wait_event_class
    , wait_event_type
    , wait_event   as   busiest_event_overall
from ybx_ash ya
   , cutoff c 
where ya.sample_time > c.sincedt
group by wait_event_class, wait_event_type, wait_event
order by 1 desc 
limit 40;

with cutoff as ( select now() - make_interval ( secs=>:n_sec ) as sincedt ) 
select count (*) cnt
    , wait_event_class
    , wait_event_type
    , wait_event      as  busiest_event
    , ya.host         as  per_host
from ybx_ash ya
   , cutoff c 
where ya.sample_time > c.sincedt
group by wait_event_class, wait_event_type, wait_event, host
order by 1 desc 
limit 40;

-- -- -- now check for busiest tables and tablets..

with cutoff as ( select now() - make_interval ( secs=>:n_sec ) as sincedt ) 
select count (*)  cnt
    , wait_event_aux
    , ya.host
from ybx_ash ya
   , cutoff c 
where ya.sample_time > c.sincedt
  and ya.wait_event_aux is not null
group by --         wait_event_class, wait_event_type
         wait_event_aux, host
order by 1 desc 
limit 20;

select count (*)  cnt
    ,             a.host
    ,             yt.ysql_schema_name
    ,             yt.table_name
from ybx_ash a
   , ybx_tblt yt 
where 1=1
and   substr ( yt.tablet_id, 1, 15) = a.wait_event_aux  
and   yt.host = a.host     -- on same host as ahs-record
and   yt.gone_time is null -- only active tablets
and   a.sample_time > ( now() - make_interval ( secs=>:n_sec ) )
and   a.wait_event_aux is not null
group by a.host, yt.ysql_schema_name, yt.table_name 
order by 1 desc, 2 
limit 20 ;

\! echo above the busiest tablets per host.
\! echo  next some aggregates over total ash-table
select count (*)  cnt
    ,             a.host
    ,             a.wait_event_aux
    ,             yt.ysql_schema_name
    ,             yt.table_name
from ybx_ash a
   , ybx_tblt yt 
where 1=1
and   substr ( yt.tablet_id, 1, 15) = a.wait_event_aux  
and   yt.host = a.host     -- on same host as ahs-record
and   yt.gone_time is null -- only active tablets
and   a.sample_time > ( now() - make_interval ( secs=>:n_sec ) )
and   a.wait_event_aux is not null
-- and wait_event_component not in ('YCQL')
group by a.host, a.wait_event_aux, yt.ysql_schema_name, yt.table_name 
order by 1 desc, 2 
limit 30 ;

\! echo above the busiest tablets per host.
\! echo  next some aggregates over total ash-table
\! echo .
\! read -t 10 -p "5. next per event and per host ..." abc

\! echo .
\! echo .

select count (*), a.wait_event_type
from ybx_ash a
where 1=1
--and wait_event_component not in ('YCQL') 
and a.sample_time > ( now() - make_interval (secs => :n_sec ) ) 
group by  a.wait_event_type
order by 1 desc ; 

\! read -t 10 -p "above the w-e types in last interval.." abc
\! echo .
\! echo .

select count (*), a.host, a.wait_event_type
from ybx_ash a
where 1=1
--and wait_event_component not in ('YCQL') 
and a.sample_time > ( now() - make_interval (secs => :n_sec ) ) 
group by  a.host, a.wait_event_type
order by a.host, 1 desc ;


/*** 
select count (*), a.wait_event_component
from ybx_ash a
-- where wait_event_component not in ('YCQL') 
group by a.wait_event_component 
order by 1 desc ; 

select count (*), a.host, a.wait_event_component
from ybx_ash a
-- where wait_event_component not in ('YCQL') 
group by a.host, a.wait_event_component 
order by a.host, 1 desc ; 


select count (*), a.wait_event_class 
from ybx_ash a
--where wait_event_component not in ('YCQL') 
group by a.wait_event_class 
order by 1 desc ; 

select count (*), a.host, a.wait_event_class 
from ybx_ash a
--where wait_event_component not in ('YCQL') 
group by a.host, a.wait_event_class 
order by a.host, 1 desc ; 

***/ 

select count (*)  as    cnt
     ,                  a.wait_event 
from ybx_ash a
where 1=1
and a.sample_time > ( now() - make_interval (secs => :n_sec ) ) 
group by a.wait_event 
order by 1 desc ; 

select count (*) as     cnt
     , a.host    as     per_host
     ,                  a.wait_event 
from ybx_ash a
where 1=1
and a.sample_time > ( now() - make_interval (secs => :n_sec ) ) 
group by a.host, a.wait_event 
order by a.host, 1 desc ; 


select                count (*)
    ,                 a.wait_event_aux
    ,                 yt.ysql_schema_name
    ,                 yt.table_name
from ybx_ash a
   , ybx_tblt yt 
where 1=1
and substr ( yt.tablet_id, 1, 15) = a.wait_event_aux  
and a.sample_time > ( now() - make_interval ( secs=>:n_sec ) )
and wait_event_aux is not null
-- and wait_event_component not in ('YCQL')
group by a.wait_event_aux, yt.ysql_schema_name, yt.table_name 
order by 1 desc 
limit 20 ;

select count (*)  as  cnt
    ,                 a.host
    ,                 a.wait_event_aux
    ,                 yt.ysql_schema_name
    ,                 yt.table_name
from ybx_ash a
   , ybx_tblt yt 
where 1=1
and substr ( yt.tablet_id, 1, 15) = a.wait_event_aux  
and a.sample_time > ( now() - make_interval ( secs=>:n_sec ) )
and wait_event_aux is not null
-- and wait_event_component not in ('YCQL')
group by a.host, a.wait_event_aux, yt.ysql_schema_name, yt.table_name 
order by a.host, 1 desc 
limit 30 ;

\! read -t 10 -p "7. above: table_names, next checking top-level node-ids aux..." abc
\! echo .
\! echo .


-- find queries, and later: top-root-req, to see if many rreq 
select count (*)
    --, min (sample_time) , max(sample_time)
    , count ( distinct ya.root_request_id  )    nr_rreq
    , ya.query_id                               top_qry
    , substr ( q.query, 1, 200)              as Query
    --, max ( substr ( ya.query, 1, 200)  )  as Query
from ybx_ash ya 
   , ybx_pgs_stmt q
where 1=1
and   ya.query_id = q.queryid
and   ya.root_request_id::text not like '000%'
and   ya.sample_time > ( now() - make_interval ( secs=>:n_sec ) )
--and ya.root_request_id::text like 'd1dc9%'
group by ya.query_id, q.query
order by 1 desc 
limit 20;


/* ****** *
-- find top root_request, with most counts..
-- note: clientRead seems to signify "at client", or "idle-at-client"
select count (*)
    --, min (sample_time) , max(sample_time)
    , ya.root_request_id  top_root_req
    , ya.query_id         top_qry
from ybx_ash ya 
where ya.root_request_id::text not like '000%'
and ya.sample_time > ( now() - make_interval ( secs=>:n_sec ) )
--and ya.root_request_id::text like 'd1dc9%'
group by ya.root_request_id , ya.query_id
order by 1 desc 
limit 20;

-- note: above and below: resutls dont seem to concur.. 
-- reasond: not all root-req have a query, and 
-- possible bcse records get inserted inbetween ? 

* ****** */

-- try looking for qry via id, using saved pgs_stmnt
select count (*)
    --, min (sample_time) , max(sample_time)
    , substr ( ya.root_request_id::text, 1, 9)    as    top_root_req
    , ya.query_id                                 as    top_qry
    , max ( substr ( query, 1, 100)  )            as    Query
from ybx_ash ya 
   , ybx_pgs_stmt q
where 1=1
and   q.queryid                 =     ya.query_id
and   ya.root_request_id::text  not   like '000%'
and   ya.sample_time            >     ( now() - make_interval ( secs=>:n_sec ) )
group by ya.root_request_id , ya.query_id
order by 1 desc 
limit 20;

-- try looking for qry via id, using saved pgs_stmnt

select 'Also find originating client_ip, port, session' Notes ;


\! echo .
\! read -t 10 -p "8. above: queries, next checking per interval ..." abc
\! echo .
\! echo .


select  
        to_char ( a.sample_time, 'DY HH24:MI') as   dt_minute
      ,                                             a.host 
      , count (*)                                   samples_per_min
from ybx_ash a
where a.sample_time > ( now() - make_interval ( secs=>:n_sec ) )
--and wait_event_component not in ('YCQL') 
group by 
  host, to_char ( a.sample_time, 'DY HH24:MI') 
order by 2, 1  ; 

with cutoff as ( select now() - make_interval (secs => :n_sec )  as sincedt ) 
select  
  to_char ( a.sample_time, 'DDD DY HH24:00') as     dt_hr
,            a.host 
, count (*)  samples_per_hr
from ybx_ash a
   , cutoff c
where 1=1 
--and wait_event_component not in ('YCQL') 
and a.sample_time > c.sincedt
group by 
  host, to_char ( a.sample_time, 'DDD DY HH24:00')
order by 2, 1  ; 

with cutoff as ( select now() - make_interval (secs => :n_sec )  as sincedt ) 
select  
  to_char ( a.sample_time, 'D DY HH24:MI DDD') as dt_minute
  --, a.host
, count (*) cnt_cpu_passive_per_min
from ybx_ash a
   , cutoff c
where 1=1 
--and wait_event_component not in ('YCQL')
and a.wait_event = 'OnCpu_Passive'
and a.sample_time > c.sincedt
group by 
  --host, 
  to_char ( a.sample_time, 'D DY HH24:MI DDD')
  having count(*) > 5
order by 1, 2 ; 
 
\! read -t 10 -p "10. above, check per timeslot..." abc
\! echo .
\! echo .

-- this seems to work..
select  count (*)                             cnt 
      ,                                       ash.client_node_ip
      , substr ( psa.application_name, 1, 15) app_name
      , substr ( psa.query, 1, 60 )           query__
from ybx_ash ash  
 --gv$yb_active_session_history  ash
 , ybx_pgs_act psa
--ybx_ash ash
 where 1=1 
 and ash.client_node_ip = host (psa.client_addr) || ':' || psa.client_port
-- and psa.state ='active'
and query not like '%get_ash%'
and ash.sample_time  > ( now() - make_interval ( secs=> :n_sec ) )
group by 2, 3, 4 
having count(*) > 1
order by 1 desc ; 

