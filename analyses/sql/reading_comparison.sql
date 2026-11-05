-- Question: what would each reading of "deals at a step" give, stage by stage?
-- Backs: the readings table in docs/technical_documentation.md, section 9.
-- Result on this extract: 13,003 movement, 8,860 recorded stage changes, 5,517 last stage, 4,539 month-end positions.
with stage_steps as (

    select stage_id, kpi_name, funnel_step, step_order
    from {{ ref('funnel_steps') }}
    where stage_id is not null

),

movement as (

    select funnel_step, sum(deals_count) as deals
    from {{ ref('rep_sales_funnel_monthly') }}
    group by 1

),

recorded as (

    select stage_id, count(*) as deals
    from (
        select distinct deal_id, stage_id, entered_month
        from {{ ref('fct_deal_stage_entry') }}
        where not is_skipped_stage
    ) as recorded_entries
    group by 1

),

last_stage as (

    select stage_id, count(*) as deals
    from (
        select distinct on (deal_id, entered_month) stage_id
        from {{ ref('fct_deal_stage_entry') }}
        order by deal_id, entered_month, entered_at desc, stage_id desc
    ) as last_entries
    group by 1

),

month_end as (

    select funnel_step, sum(deals_count) as deals
    from {{ ref('rep_deal_stage_distribution_monthly') }}
    group by 1

),

readings as (

    select
        stage_steps.step_order,
        stage_steps.kpi_name,
        movement.deals as movement,
        recorded.deals as recorded_stage_changes,
        last_stage.deals as last_stage_each_month,
        month_end.deals as month_end_distribution
    from stage_steps
    inner join movement on stage_steps.funnel_step = movement.funnel_step
    inner join recorded on stage_steps.stage_id = recorded.stage_id
    inner join last_stage on stage_steps.stage_id = last_stage.stage_id
    inner join month_end on stage_steps.funnel_step = month_end.funnel_step

)

select kpi_name, movement, recorded_stage_changes, last_stage_each_month, month_end_distribution
from readings

union all

select 'Total', sum(movement), sum(recorded_stage_changes), sum(last_stage_each_month), sum(month_end_distribution)
from readings

order by movement desc
