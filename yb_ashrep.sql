/*

file : yb_ashrep: report the top-events from ash.

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

