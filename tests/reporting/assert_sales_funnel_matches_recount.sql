-- Compares every month and step of the report with a recount from ods_, zeros included.
-- Runs after the report builds, so a failure flags a wrong report rather than holding it back.
with months as (

    {{ recount_months() }}

),

stage_steps as (

    select
        stage_id,
        lower(stage_name) as step_key
    from {{ ref('ods_pipedrive__stages') }}

),

call_steps as (

    select lower(activity_type_name) as step_key
    from {{ ref('ods_pipedrive__activity_types') }}
    where activity_type_name like 'Sales Call %'

),

steps as (

    select step_key from stage_steps
    union all
    select step_key from call_steps

),

recount as (

    select
        stage_entries.month,
        stage_steps.step_key,
        stage_entries.deals_count
    from ({{ recount_stage_entries() }}) as stage_entries
    inner join stage_steps
        on stage_entries.stage_id = stage_steps.stage_id

    union all

    select
        month,
        lower(kpi_name),
        deals_count
    from ({{ recount_call_steps() }}) as call_entries

),

expected_cells as (

    select
        months.month,
        steps.step_key,
        coalesce(recount.deals_count, 0)::integer as deals_count
    from months
    cross join steps
    left join recount
        on months.month = recount.month
        and steps.step_key = recount.step_key

),

report_cells as (

    select
        month,
        kpi_name,
        funnel_step,
        lower(kpi_name) as step_key,
        deals_count
    from {{ ref('rep_sales_funnel_monthly') }}

)

select
    coalesce(report_cells.month, expected_cells.month) as month,
    coalesce(report_cells.kpi_name, expected_cells.step_key) as kpi_name,
    report_cells.funnel_step,
    report_cells.deals_count as report_count,
    expected_cells.deals_count as recount
from report_cells
full join expected_cells
    on report_cells.month = expected_cells.month
    and report_cells.step_key = expected_cells.step_key
where report_cells.deals_count is distinct from expected_cells.deals_count
