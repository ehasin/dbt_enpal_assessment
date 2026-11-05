-- One row per activity type. A type is a sales call when its source name is a step in the funnel.
select
    activity_types.activity_type,
    activity_types.activity_type_name,
    activity_types.is_active,
    funnel_steps.kpi_name is not null as is_sales_call
from {{ ref('ods_pipedrive__activity_types') }} as activity_types
left join {{ ref('funnel_steps') }} as funnel_steps
    on activity_types.activity_type_name = funnel_steps.kpi_name
