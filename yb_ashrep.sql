/*

file : yb_ashrep: report the top-events from ash.

notes:
 - it is a SAMPLE.. not a stopwatch-timer.

todo:
 - think of graphic visual, how to display...
 - get meaning of wait-events.
 - capacity : list of "idle" events, e.g. not consuming thread or cpu on server
 - network: how to measure ?
 - link aux to table
 - add top-request, + link to SQL

*/


-- busiest nodes
with cutoff as ( select now() - interval '900 seconds' as sincedt ) 
select count (*) cnt, sincedt, host as busiest
from ybx_ash ya
   , cutoff c 
where ya.sample_time > c.sincedt
group by sincedt, sincedt, host 
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
select count (*) cnt, wait_event_class, host
from ybx_ash ya
   , cutoff c 
where ya.sample_time > c.sincedt
group by wait_event_class, host
order by 1 desc 
limit 20;

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
limit 20;

-- -- -- now check for busiest tablets..

with cutoff as ( select now() - interval '900 seconds' as sincedt ) 
select count (*) cnt, wait_event_class, wait_event_type, wait_event, wait_event_aux, host
from ybx_ash ya
   , cutoff c 
where ya.sample_time > c.sincedt
  and ya.wait_event_aux is not null
group by wait_event_class, wait_event_type, wait_event, wait_event_aux, host
order by 1 desc 
limit 20;

\! echo next some aggregates over total ash-table
\! read -t 10 -p "next are sum-samples per class, per type, per aux..." abc


select count (*), a.wait_event_type
from ybx_ash a
-- where wait_event_component not in ('YCQL') 
group by  a.wait_event_type
order by 1 desc ; 

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
and wait_event_aux is not null
-- and wait_event_component not in ('YCQL')
group by a.host, a.wait_event_aux, yt.ysql_schema_name, yt.table_name 
order by a.host, 1 desc 
limit 40 ;


\! read -t 10 -p "next checking top-level node-ids aux..." abc

select count (*), a.top_level_node_id
from ybx_ash a
--where wait_event_component not in ('YCQL') 
group by a.top_level_node_id
order by 1 desc ; 


select count (*), a.top_level_node_id, a.host
from ybx_ash a
--where wait_event_component not in ('YCQL') 
group by a.top_level_node_id, a.host
order by a.host, 1 desc ; 
