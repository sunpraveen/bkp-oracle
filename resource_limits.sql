-- Find resource usage limits for RAC - all resources that are being used with utilization > 80
col resource_name for a30
col INITIAL_ALLOCATION for a20
col limit_value for a20
set pages 50000 lines 400 feed on timing on
select GVRL.INST_ID, GVRL.RESOURCE_NAME, CURRENT_UTILIZATION, LIMIT_VALUE , round( (CURRENT_UTILIZATION/to_number(decode(LIMIT_VALUE,0,1,LIMIT_VALUE)))*100) "PCT"
from
GV$RESOURCE_LIMIT GVRL,
(select INST_ID,RESOURCE_NAME
from GV$RESOURCE_LIMIT
where LIMIT_VALUE not like '%UNLIMITED%'
and LIMIT_VALUE not like '0'
and CURRENT_UTILIZATION > 0
and round((CURRENT_UTILIZATION/to_number(decode(LIMIT_VALUE,0,1,LIMIT_VALUE)))*100) > 80
) B
where  GVRL.INST_ID = B.INST_ID
AND GVRL.RESOURCE_NAME = B.RESOURCE_NAME
;
