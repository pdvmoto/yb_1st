/*

*/

\timing on

select 'doing ASH on : ' || ybx_get_host() as title ;

select ybx_get_ash () ash_collected;  

select get_tablets () tablets_processed ; 

select ybx_get_evlst() as added_events;

