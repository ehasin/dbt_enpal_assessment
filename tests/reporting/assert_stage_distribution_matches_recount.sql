-- Compares every month and stage of the month-end report with a recount from ods_, zeros included.
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

expected_cells as (

    select
        months.month,
        stage_steps.step_key,
        coalesce(recount.deals_count, 0)::integer as deals_count
    from months
    cross join stage_steps
    left join ({{ recount_stage_distribution() }}) as recount
        on months.month = recount.month
        and stage_steps.stage_id = recount.stage_id

),

report_cells as (

    select
        month,
        kpi_name,
        funnel_step,
        lower(kpi_name) as step_key,
        deals_count
    from {{ ref('rep_deal_stage_distribution_monthly') }}

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
