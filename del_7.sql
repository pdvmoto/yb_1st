

delete from ybx_ashy_log  al
where al.id in ( 
select id from ybx_ashy_log l2
where l2.query_id = 5 
  and l2.wait_event like 'Exten%'
limit 5000 ) ; 

