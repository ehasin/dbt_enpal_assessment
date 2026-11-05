-- The publish gate. Any fail row here stops all three output ports, which keep their last good version.
select *
from {{ ref('rep_data_quality_checks') }}
where status = 'fail'
