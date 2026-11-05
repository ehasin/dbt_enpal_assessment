-- Question: how much does each assumption change the numbers, against each alternative not chosen?
-- Backs: the sensitivity table in docs/technical_documentation.md, section 9.
-- Numbers refer to the assumptions in docs/methodology_and_assumptions.md. Sums measure the difference only:
-- they aren't reported KPIs. Movement and position are two measures, so that row is no error or uplift.
with stage_steps as (

    select stage_id, funnel_step
    from {{ ref('funnel_steps') }}
    where stage_id is not null

),

call_steps as (

    select dim_activity_type.activity_type, funnel_steps.funnel_step
    from {{ ref('dim_activity_type') }} as dim_activity_type
    inner join {{ ref('funnel_steps') }} as funnel_steps
        on dim_activity_type.activity_type_name = funnel_steps.kpi_name

),

report as (

    select
        report.month,
        report.funnel_step,
        report.deals_count,
        case when funnel_steps.stage_id is null then 'call' else 'stage' end as population
    from {{ ref('rep_sales_funnel_monthly') }} as report
    inner join {{ ref('funnel_steps') }} as funnel_steps
        on report.funnel_step = funnel_steps.funnel_step

),

month_end_report as (

    select month, funnel_step, deals_count
    from {{ ref('rep_deal_stage_distribution_monthly') }}

),

stage_entries as (

    select * from {{ ref('fct_deal_stage_entry') }}

),

sales_calls as (

    select fct_activity.*, call_steps.funnel_step
    from {{ ref('fct_activity') }} as fct_activity
    inner join call_steps
        on fct_activity.activity_type = call_steps.activity_type

),

-- Assumption 3: the same movement logic over rows the report excludes.
all_stage_moves as (

    select
        deal_id,
        new_value::integer as stage_id,
        changed_at,
        lag(new_value::integer) over (partition by deal_id order by changed_at, new_value::integer) as previous_stage_id
    from {{ ref('fct_deal_change') }}
    where changed_field = 'stage_id'

),

latest_creations as (

    select deal_id, max(changed_at) as created_at
    from {{ ref('fct_deal_change') }}
    where changed_field = 'add_time'
    group by deal_id

),

moves_after_latest_creation as (

    select
        moves.deal_id,
        moves.stage_id,
        moves.changed_at,
        lag(moves.stage_id) over (partition by moves.deal_id order by moves.changed_at, moves.stage_id) as previous_stage_id
    from all_stage_moves as moves
    inner join latest_creations
        on moves.deal_id = latest_creations.deal_id
    where moves.changed_at >= latest_creations.created_at
        or moves.deal_id not in (
            select deal_id from {{ ref('fct_deal_change') }} where dq_reason is not null
        )

),

deals_lost_after_implementation as (

    select dim_deal.deal_id
    from {{ ref('dim_deal') }} as dim_deal
    inner join stage_entries
        on dim_deal.deal_id = stage_entries.deal_id
        and stage_entries.stage_id = 7
    where dim_deal.lost_at >= stage_entries.entered_at

),

sales_call_2_without_call_1 as (

    select second_call.activity_id
    from sales_calls as second_call
    left join sales_calls as first_call
        on second_call.deal_id = first_call.deal_id
        and first_call.activity_type = 'meeting'
        and first_call.due_at < second_call.due_at
    where second_call.activity_type = 'sc_2'
        and first_call.activity_id is null

),

earliest_row_per_activity_id as (

    select distinct on (activity_id) *
    from {{ ref('fct_activity') }}
    order by activity_id, due_at

),

one_row_per_activity_id as (

    select earliest_row.*, call_steps.funnel_step
    from earliest_row_per_activity_id as earliest_row
    inner join call_steps
        on earliest_row.activity_type = call_steps.activity_type

),

months_with_deals as (

    select
        dim_month.month,
        dim_month.month_end,
        dim_deal.deal_id,
        dim_deal.first_stage_entered_at,
        dim_deal.lost_at,
        dim_deal.deal_created_at
    from {{ ref('dim_month') }} as dim_month
    cross join {{ ref('dim_deal') }} as dim_deal

),

extended_months as (

    select month_start::date as month
    from generate_series(
        (select max(month) + interval '1 month' from report),
        (
            select date_trunc('month', max(changed_at))
            from {{ ref('fct_deal_change') }}
            where changed_field = 'lost_reason'
        ),
        interval '1 month'
    ) as month_start

),

alternatives as (

    select 'Key' as assumption, 'Only calls linked to a deal' as alternative, 'call' as population,
        due_month as month, funnel_step, count(distinct deal_id) as deals_count
    from sales_calls
    where dq_reason is null and is_done and has_deal_history
    group by 4, 5

    union all

    select '1', 'Only recorded stage changes', 'stage',
        entered_month, stage_steps.funnel_step, count(distinct deal_id)
    from stage_entries
    inner join stage_steps on stage_entries.stage_id = stage_steps.stage_id
    where not is_skipped_stage
    group by 4, 5

    union all

    select '1', 'Only a deal''s last stage each month', 'stage', month, funnel_step, count(*)
    from (
        select distinct on (deal_id, entered_month)
            entered_month as month,
            stage_steps.funnel_step
        from stage_entries
        inner join stage_steps on stage_entries.stage_id = stage_steps.stage_id
        order by deal_id, entered_month, entered_at desc, stage_entries.stage_id desc
    ) as last_stages
    group by 4, 5

    union all

    select '1', 'Month-end deal / stage distribution (a different measure)', 'stage', month, funnel_step, deals_count
    from month_end_report

    union all

    select '2', 'All scheduled calls', 'call', due_month, funnel_step, count(distinct deal_id)
    from sales_calls
    where dq_reason is null
    group by 4, 5

    union all

    select '3', 'Keeping everything', 'all',
        date_trunc('month', moves.changed_at)::date, stage_steps.funnel_step, count(distinct moves.deal_id)
    from all_stage_moves as moves
    cross join lateral generate_series(
        case when moves.stage_id > moves.previous_stage_id then moves.previous_stage_id + 1 else moves.stage_id end,
        moves.stage_id
    ) as filled(stage_id)
    inner join stage_steps on filled.stage_id = stage_steps.stage_id
    group by 4, 5

    union all

    select '3', 'Keeping everything', 'all', due_month, funnel_step, count(distinct deal_id)
    from sales_calls
    where is_done
    group by 4, 5

    union all

    select '3', 'Keeping one of the conflicting records', 'all',
        date_trunc('month', moves.changed_at)::date, stage_steps.funnel_step, count(distinct moves.deal_id)
    from moves_after_latest_creation as moves
    cross join lateral generate_series(
        case when moves.stage_id > moves.previous_stage_id then moves.previous_stage_id + 1 else moves.stage_id end,
        moves.stage_id
    ) as filled(stage_id)
    inner join stage_steps on filled.stage_id = stage_steps.stage_id
    group by 4, 5

    union all

    select '3', 'Keeping one of the conflicting records', 'all', due_month, funnel_step, count(distinct deal_id)
    from one_row_per_activity_id
    where is_done
    group by 4, 5

    union all

    select '3', 'Removing unusual records', 'all',
        entered_month, stage_steps.funnel_step, count(distinct deal_id)
    from stage_entries
    inner join stage_steps on stage_entries.stage_id = stage_steps.stage_id
    where deal_id not in (select deal_id from deals_lost_after_implementation)
    group by 4, 5

    union all

    select '3', 'Removing unusual records', 'all', due_month, funnel_step, count(distinct deal_id)
    from sales_calls
    where dq_reason is null
        and is_done
        and activity_id not in (select activity_id from sales_call_2_without_call_1)
    group by 4, 5

    union all

    -- One way to guess: a deal that reached Implementation counts as won, so it stops being open.
    select '4', 'Guessing won deals from how far they got', 'month_end', month, funnel_step, deals_count
    from month_end_report
    inner join stage_steps using (funnel_step)
    where stage_steps.stage_id < 7

    union all

    select '5', 'Fixed dates: calendar 2024', 'all', month, funnel_step, deals_count
    from report
    where month < date '2025-01-01'

    union all

    select '5', 'Running to the last lost reason', 'all', month, funnel_step, deals_count
    from report

    union all

    select '5', 'Running to the last lost reason', 'all', extended_months.month, funnel_steps.funnel_step, 0
    from extended_months
    cross join {{ ref('funnel_steps') }} as funnel_steps

    union all

    select '5', 'Leaving out empty months', 'all', month, funnel_step, deals_count
    from report
    where deals_count > 0

    union all

    select '6', 'Showing Deal Created as a step', 'all', month, funnel_step, deals_count
    from report

    union all

    select '6', 'Showing Deal Created as a step', 'all',
        date_trunc('month', deal_created_at)::date, 'Deal Created', count(*)
    from {{ ref('dim_deal') }}
    group by 4, 5

    union all

    select '6', 'Dating Lead Generation by deal creation', 'step_1',
        date_trunc('month', deal_created_at)::date, 'Step 1', count(*)
    from {{ ref('dim_deal') }}
    group by 4, 5

    union all

    select '6', 'Treating the gap as real: a No stage yet row at month end', 'month_end', month, funnel_step, deals_count
    from month_end_report

    union all

    select '6', 'Treating the gap as real: a No stage yet row at month end', 'month_end', month, 'No stage yet', count(*)
    from months_with_deals
    where deal_created_at::date <= month_end
        and first_stage_entered_at::date > month_end
        and (lost_at is null or lost_at::date > month_end)
    group by 4, 5

),

scopes as (

    select distinct assumption, alternative, population
    from alternatives

),

chosen as (

    select scopes.assumption, scopes.alternative, report.month, report.funnel_step, report.deals_count
    from scopes
    inner join report
        on scopes.population = report.population
        or scopes.population = 'all'
        or (scopes.population = 'step_1' and report.funnel_step = 'Step 1')

    union all

    select scopes.assumption, scopes.alternative, month_end_report.month, month_end_report.funnel_step, month_end_report.deals_count
    from scopes
    cross join month_end_report
    where scopes.population = 'month_end'

),

alternative_cells as (

    select assumption, alternative, month, funnel_step, sum(deals_count) as deals_count
    from alternatives
    group by 1, 2, 3, 4

),

compared as (

    select
        coalesce(chosen.assumption, alternative_cells.assumption) as assumption,
        coalesce(chosen.alternative, alternative_cells.alternative) as alternative,
        chosen.deals_count as chosen_count,
        alternative_cells.deals_count as alternative_count
    from chosen
    full join alternative_cells
        on chosen.assumption = alternative_cells.assumption
        and chosen.alternative = alternative_cells.alternative
        and chosen.month = alternative_cells.month
        and chosen.funnel_step = alternative_cells.funnel_step

)

select
    assumption,
    alternative,
    coalesce(sum(chosen_count), 0) as sum_chosen,
    coalesce(sum(alternative_count), 0) as sum_alternative,
    count(chosen_count) as cells_chosen,
    count(alternative_count) as cells_alternative,
    count(*) filter (where coalesce(chosen_count, 0) <> coalesce(alternative_count, 0)) as cells_changed,
    max(abs(coalesce(chosen_count, 0) - coalesce(alternative_count, 0))) as largest_cell_change
from compared
group by 1, 2
order by 1, 2
