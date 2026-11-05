-- The month-end report: estimated open deals in each stage at month end. Calls have no month-end state.
-- depends_on: {{ ref('rep_data_quality_checks') }}
with position_counts as (

    select
        month,
        stage_id,
        count(*) as deals_count
    from {{ ref('fct_deal_stage_month_end') }}
    group by 1, 2

)

select
    dim_month.month,
    funnel_steps.kpi_name,
    funnel_steps.funnel_step,
    coalesce(position_counts.deals_count, 0)::integer as deals_count
from {{ ref('dim_month') }} as dim_month
inner join {{ ref('funnel_steps') }} as funnel_steps
    on funnel_steps.stage_id is not null
left join position_counts
    on dim_month.month = position_counts.month
    and funnel_steps.stage_id = position_counts.stage_id
order by dim_month.month, funnel_steps.step_order
