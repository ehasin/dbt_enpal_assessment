-- One row per pipeline stage, carrying the required label next to the source's spelling.
select
    stages.stage_id,
    stages.stage_name as source_stage_name,
    funnel_steps.kpi_name
from {{ ref('ods_pipedrive__stages') }} as stages
left join {{ ref('funnel_steps') }} as funnel_steps
    on stages.stage_id = funnel_steps.stage_id
