
\set n_sec 36000.0

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

todo:
 - think of graphic visual, how to display...
 - get meaning of wait-events.
 - capacity : list of "idle" events, e.g. not consuming thread or cpu on server
 - network: how to measure ?
 - link aux to table
 - add top-request, + link to SQL
 - top-event per interval, per minute if possible..

*/

select 'ash from memory contents, local and global' as first_check ; 

select count (*) total_in_buff, min (sample_time) oldest_in_buff, max(sample_time) latest_in_buff
from yb_active_session_history ;

select count (*) total_in_buff, min (sample_time) oldest_in_buff, max(sample_time) latest_in_buff
from gv$yb_active_session_history ;

select count (*) total_in_buff,  min (sample_time) oldest_in_buff, max(sample_time) latest_in_buff, gv$host
from gv$yb_active_session_history 
group by gv$host 
order by 1 desc;

select host current_host, uuid from yb_servers () tsrv_uuid where public_ip in ( select get_host() ) ;

\echo .
\! read -t 10 -p "above: check if any data present in local and gv views... " abc
\echo .
\echo .

select 'ash data stored in DB, global on all nodes... ' as second_check ; 

select count (*) total_records, min (sample_time) oldest_rec, max(sample_time) latest_rec
from ybx_ash ;

select count (*) total_records
, min (sample_time) oldest_rec
, max(sample_time) latest_rec
, to_char (  age ( now (), max(sample_time) ), 'ssss' )  secs_ago
, host
from ybx_ash 
group by host
order by 1;

\echo .
\! read -t 10 -p "above: check data stored in ash-table(s), per hosts... " abc
\echo .
\echo .


-- busiest nodes
with cutoff as ( select now() - make_interval (secs => :n_sec )  as sincedt ) 
select count (*) cnt, sincedt, host as busiest
from ybx_ash ya
   , cutoff c 
where ya.sample_time > c.sincedt
group by sincedt, host 
order by 1 desc 
limit 10;

-- check current_node via view...
with cutoff as  
(  select now() - interval '900 seconds' as sincedt
, get_host() as host 
) 
select count (*) cnt, sincedt, host as busiest_ash
from yb_active_session_history ya
   , cutoff c 
where ya.sample_time > c.sincedt
group by sincedt, sincedt, host 
order by 1 desc 
limit 10;

-- busiest events class
with cutoff as ( select now() - interval '900 seconds' as sincedt ) 
select count (*) cnt, sincedt, wait_event_class, host
from ybx_ash ya
   , cutoff c 
where ya.sample_time > c.sincedt
group by wait_event_class, sincedt, host
order by 1 desc  
limit 30;

\echo .
\! read -t 10 -p "above: top-event per hosts... " abc
\echo .
\echo .

-- busiest events, type
with cutoff as ( select now() - interval '900 seconds' as sincedt ) 
select count (*) cnt, wait_event_type, host
from ybx_ash ya
   , cutoff c 
where ya.sample_time > c.sincedt
group by wait_event_type, host
order by 1 desc 
limit 20;

-- busiest events
with cutoff as ( select now() - interval '900 seconds' as sincedt ) 
select count (*) cnt, wait_event_class, wait_event_type, wait_event, host
from ybx_ash ya
   , cutoff c 
where ya.sample_time > c.sincedt
group by wait_event_class, wait_event_type, wait_event, host
order by 1 desc 
limit 40;

-- -- -- now check for busiest tablets..

with cutoff as ( select now() - interval '900 seconds' as sincedt ) 
select count (*) cnt, wait_event_class, wait_event_type, wait_event, wait_event_aux, host
from ybx_ash ya
   , cutoff c 
where ya.sample_time > c.sincedt
  and ya.wait_event_aux is not null
group by              wait_event_class, wait_event_type, wait_event, wait_event_aux, host
order by 1 desc 
limit 30;

\! echo above the busiest tablets per host.
\! echo  next some aggregates over total ash-table
\! read -t 10 -p "next are sum-samples per class, per type, per aux..." abc


select count (*), a.wait_event_type
from ybx_ash a
where 1=1
and wait_event_component not in ('YCQL') 
and a.sample_time > ( now() - make_interval (secs => :n_sec ) ) 
group by  a.wait_event_type
order by 1 desc ; 

\! read -t 10 -p "above the w-e types in last interval.." abc

select count (*), a.host, a.wait_event_type
from ybx_ash a
-- where wait_event_component not in ('YCQL') 
group by  a.host, a.wait_event_type
order by a.host, 1 desc ;


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

select count (*), a.wait_event 
from ybx_ash a
--where wait_event_component not in ('YCQL') 
group by a.wait_event 
order by 1 desc ; 

select count (*), a.host, a.wait_event 
from ybx_ash a
--where wait_event_component not in ('YCQL') 
group by a.host, a.wait_event 
order by a.host, 1 desc ; 

select count (*), a.wait_event_aux, yt.table_name
from ybx_ash a
   , ybx_tblt yt 
where 1=1
and substr ( yt.tablet_id, 1, 15) = a.wait_event_aux  
and a.sample_time > ( now() - make_interval ( secs=>:n_sec ) )
and wait_event_aux is not null
-- and wait_event_component not in ('YCQL')
group by a.wait_event_aux, yt.table_name 
order by 1 desc 
limit 20 ;

select count (*), a.host, a.wait_event_aux, yt.ysql_schema_name, yt.table_name
from ybx_ash a
   , ybx_tblt yt 
where 1=1
and substr ( yt.tablet_id, 1, 15) = a.wait_event_aux  
and a.sample_time > ( now() - make_interval ( secs=>:n_sec ) )
and wait_event_aux is not null
-- and wait_event_component not in ('YCQL')
group by a.host, a.wait_event_aux, yt.ysql_schema_name, yt.table_name 
order by a.host, 1 desc 
limit 40 ;

\! read -t 10 -p "above: table_names, next checking top-level node-ids aux..." abc


-- find top root_request, with most counts..
-- note: clientRead seems to signify "at client", or "idle-at-client"
select count (*)
--, min (sample_time), max(sample_time)
, ya.root_request_id top_root_req, ya.query_id top_qry
from ybx_ash ya 
where ya.root_request_id::text not like '000%'
and ya.sample_time > ( now() - make_interval ( secs=>:n_sec ) )
--and ya.root_request_id::text like 'd1dc9%'
group by ya.root_request_id , ya.query_id
order by 1 desc 
limit 20;

\! read -t 10 -p "next checking top-level node-ids aux..." abc


select  
  to_char ( a.sample_time, 'DY HH24:MI') as dt, a.host 
, count (*) samples
from ybx_ash a
where a.sample_time > ( now() - make_interval ( secs=>:n_sec ) )
--and wait_event_component not in ('YCQL') 
group by 
  host, to_char ( a.sample_time, 'DY HH24:MI') 
order by 2, 1  ; 

with cutoff as ( select now() - make_interval (secs => :n_sec )  as sincedt ) 
select  
  to_char ( a.sample_time, 'DDD DY HH24:00') as dt, a.host 
, count (*) samples
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
  to_char ( a.sample_time, 'D DY HH24:MI DDD') as dt
  --, a.host
, count (*) samples_cpu_passive
from ybx_ash a
   , cutoff c
where 1=1 
--and wait_event_component not in ('YCQL')
and a.wait_event = 'OnCpu_Passive'
and a.sample_time > c.sincedt
group by 
  --host, 
  to_char ( a.sample_time, 'D DY HH24:MI DDD')
  having count(*) > 4
order by 1 desc , 2 ; 
 
\! read -t 10 -p "above, check per timeslot..." abc

-- this seems to work..
select count (*) , ash.client_node_ip, psa.application_name , psa.query
from ybx_ash ash  
 --gv$yb_active_session_history  ash
 , ybx_pgs_act psa
--ybx_ash ash
 where 1=1 
 and ash.client_node_ip = host (psa.client_addr) || ':' || psa.client_port
 and psa.state ='active'
and query not like '%get_ash%'
 and age ( now(), ash.sample_time ) < interval '7200 seconds'
group by 2, 3, 4 
having count(*) > 1
order by 1 desc ; 

