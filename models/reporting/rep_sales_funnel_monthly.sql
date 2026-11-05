-- The required report: how many deals entered each funnel step per month. The one place stages and calls meet.
-- depends_on: {{ ref('rep_data_quality_checks') }}
with stage_counts as (

    select
        fct_deal_stage_entry.entered_month as month,
        dim_stage.kpi_name,
        count(distinct fct_deal_stage_entry.deal_id) as deals_count
    from {{ ref('fct_deal_stage_entry') }} as fct_deal_stage_entry
    inner join {{ ref('dim_stage') }} as dim_stage
        on fct_deal_stage_entry.stage_id = dim_stage.stage_id
    group by 1, 2

),

-- Calls count from activity alone: this data has no reliable link from a call to a deal.
call_counts as (

    select
        fct_activity.due_month as month,
        dim_activity_type.activity_type_name as kpi_name,
        count(distinct fct_activity.deal_id) as deals_count
    from {{ ref('fct_activity') }} as fct_activity
    inner join {{ ref('dim_activity_type') }} as dim_activity_type
        on fct_activity.activity_type = dim_activity_type.activity_type
    where fct_activity.dq_reason is null
        and fct_activity.is_done
        and dim_activity_type.is_sales_call
    group by 1, 2

),

step_counts as (

    select * from stage_counts
    union all
    select * from call_counts

)

select
    dim_month.month,
    funnel_steps.kpi_name,
    funnel_steps.funnel_step,
    coalesce(step_counts.deals_count, 0)::integer as deals_count
from {{ ref('dim_month') }} as dim_month
cross join {{ ref('funnel_steps') }} as funnel_steps
left join step_counts
    on dim_month.month = step_counts.month
    and funnel_steps.kpi_name = step_counts.kpi_name
order by dim_month.month, funnel_steps.step_order
