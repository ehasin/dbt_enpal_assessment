-- Results of the checks that run before the reports, and source coverage by month.
-- A fail row stops all three output ports. Expected values come from ods_ or fixed lists, never from accepted data alone.

{%- set source_tables = ['deal_changes', 'activity', 'users', 'stages', 'activity_types', 'fields'] %}

with source_rows as (

    {% for source_table in source_tables %}
    select
        '{{ source_table }}' as source_table,
        (select count(*) from {{ source('pipedrive', source_table) }}) as raw_rows,
        (select count(*) from {{ ref('ods_pipedrive__' ~ source_table) }}) as ods_rows
    {% if not loop.last %}union all{% endif %}
    {% endfor %}

),

ods_stage_rows as (

    select
        changed_at,
        new_value
    from {{ ref('ods_pipedrive__deal_changes') }}
    where changed_field = 'stage_id'

),

accepted_stage_rows as (

    select changed_at
    from {{ ref('fct_deal_change') }}
    where changed_field = 'stage_id'
        and dq_reason is null

),

-- A fixed list, so that surviving unrelated activities can't hide a loss of sales calls.
ods_sales_calls as (

    select due_at
    from {{ ref('ods_pipedrive__activity') }}
    where activity_type in ('meeting', 'sc_2')

),

accepted_sales_calls as (

    select due_at
    from {{ ref('fct_activity') }}
    where activity_type in ('meeting', 'sc_2')
        and dq_reason is null

),

monthly_rows as (

    select
        dim_month.month,
        dim_month.month_end,
        (select count(*) from ods_stage_rows
            where date_trunc('month', changed_at)::date = dim_month.month) as ods_stage_rows,
        (select count(*) from accepted_stage_rows
            where date_trunc('month', changed_at)::date = dim_month.month) as accepted_stage_rows,
        (select count(*) from ods_sales_calls
            where date_trunc('month', due_at)::date = dim_month.month) as ods_sales_calls,
        (select count(*) from accepted_sales_calls
            where date_trunc('month', due_at)::date = dim_month.month) as accepted_sales_calls
    from {{ ref('dim_month') }} as dim_month

),

raw_tables_loaded as (

    select
        'raw_tables_loaded' as check_name,
        'raw' as layer,
        null::date as month,
        'fail' as severity,
        count(*)::numeric as expected_value,
        count(*) filter (where raw_rows > 0)::numeric as actual_value,
        count(*) filter (where raw_rows = 0) = 0 as is_passing,
        coalesce('Empty tables: ' || string_agg(source_table, ', ') filter (where raw_rows = 0), 'All tables have rows') as detail
    from source_rows

),

exact_duplicates_in_raw as (

    select
        'exact_duplicates_in_raw' as check_name,
        'ods' as layer,
        null::date as month,
        'warn' as severity,
        sum(ods_rows)::numeric as expected_value,
        sum(raw_rows)::numeric as actual_value,
        sum(ods_rows) = sum(raw_rows) as is_passing,
        'Raw rows against rows after exact-row dedup. The reports stay correct either way' as detail
    from source_rows

),

stage_row_acceptance_rate as (

    select
        'stage_row_acceptance_rate' as check_name,
        'core' as layer,
        null::date as month,
        'fail' as severity,
        {{ var('min_stage_row_acceptance_rate') }}::numeric as expected_value,
        round((select count(*) from accepted_stage_rows)::numeric / nullif(count(*), 0), 4) as actual_value,
        coalesce(
            (select count(*) from accepted_stage_rows)::numeric / nullif(count(*), 0)
                >= {{ var('min_stage_row_acceptance_rate') }},
            false
        ) as is_passing,
        'Accepted share of stage rows, against the lowest allowed share' as detail
    from ods_stage_rows

),

sales_call_acceptance_rate as (

    select
        'sales_call_acceptance_rate' as check_name,
        'core' as layer,
        null::date as month,
        'fail' as severity,
        {{ var('min_sales_call_acceptance_rate') }}::numeric as expected_value,
        round((select count(*) from accepted_sales_calls)::numeric / nullif(count(*), 0), 4) as actual_value,
        coalesce(
            (select count(*) from accepted_sales_calls)::numeric / nullif(count(*), 0)
                >= {{ var('min_sales_call_acceptance_rate') }},
            false
        ) as is_passing,
        'Accepted share of sales call rows, against the lowest allowed share' as detail
    from ods_sales_calls

),

accepted_plus_review_balances as (

    select
        'accepted_plus_review_balances' as check_name,
        'core' as layer,
        null::date as month,
        'fail' as severity,
        ods.ods_rows::numeric as expected_value,
        (accepted.accepted_rows + review.review_rows)::numeric as actual_value,
        ods.ods_rows = accepted.accepted_rows + review.review_rows as is_passing,
        'Accepted plus flagged rows against ods_ rows, deal changes and activities together' as detail
    from (
        select sum(ods_rows) as ods_rows
        from source_rows
        where source_table in ('deal_changes', 'activity')
    ) as ods
    cross join (
        select
            (select count(*) from {{ ref('fct_deal_change') }} where dq_reason is null)
            + (select count(*) from {{ ref('fct_activity') }} where dq_reason is null) as accepted_rows
    ) as accepted
    cross join (
        select count(*) as review_rows from {{ ref('rep_records_for_review') }}
    ) as review

),

accepted_data_in_every_month as (

    select
        'accepted_data_in_every_month' as check_name,
        'core' as layer,
        month,
        'fail' as severity,
        ((ods_stage_rows > 0)::integer + (ods_sales_calls > 0)::integer)::numeric as expected_value,
        (
            (ods_stage_rows > 0 and accepted_stage_rows > 0)::integer
            + (ods_sales_calls > 0 and accepted_sales_calls > 0)::integer
        )::numeric as actual_value,
        (ods_stage_rows = 0 or accepted_stage_rows > 0)
            and (ods_sales_calls = 0 or accepted_sales_calls > 0) as is_passing,
        'Sources with rows this month, against sources with accepted rows this month' as detail
    from monthly_rows

),

funnel_steps_complete as (

    select
        'funnel_steps_complete' as check_name,
        'seed' as layer,
        null::date as month,
        'fail' as severity,
        count(required_steps.funnel_step)::numeric as expected_value,
        count(*) filter (where required_steps.funnel_step = funnel_steps.funnel_step)::numeric as actual_value,
        count(*) filter (where required_steps.funnel_step is distinct from funnel_steps.funnel_step) = 0 as is_passing,
        'Funnel steps in the seed that match the required list, name and number' as detail
    from (
        values
            ('Step 1', 'Lead Generation'),
            ('Step 2', 'Qualified Lead'),
            ('Step 2.1', 'Sales Call 1'),
            ('Step 3', 'Needs Assessment'),
            ('Step 3.1', 'Sales Call 2'),
            ('Step 4', 'Proposal/Quote Preparation'),
            ('Step 5', 'Negotiation'),
            ('Step 6', 'Closing'),
            ('Step 7', 'Implementation/Onboarding'),
            ('Step 8', 'Follow-up/Customer Success'),
            ('Step 9', 'Renewal/Expansion')
    ) as required_steps (funnel_step, kpi_name)
    full join {{ ref('funnel_steps') }} as funnel_steps
        on required_steps.funnel_step = funnel_steps.funnel_step
        and required_steps.kpi_name = funnel_steps.kpi_name

),

stage_cells as (

    select
        coalesce(core_counts.month, recount.month) as month,
        core_counts.deals_count as core_count,
        recount.deals_count as recount_count
    from (
        select
            entered_month as month,
            stage_id,
            count(distinct deal_id) as deals_count
        from {{ ref('fct_deal_stage_entry') }}
        group by 1, 2
    ) as core_counts
    full join ({{ recount_stage_entries() }}) as recount
        on core_counts.month = recount.month
        and core_counts.stage_id = recount.stage_id

),

stage_steps_reconcile as (

    select
        'stage_steps_reconcile' as check_name,
        'core' as layer,
        dim_month.month,
        'fail' as severity,
        coalesce(sum(stage_cells.recount_count), 0)::numeric as expected_value,
        coalesce(sum(stage_cells.core_count), 0)::numeric as actual_value,
        count(*) filter (where stage_cells.core_count is distinct from stage_cells.recount_count) = 0 as is_passing,
        count(*) filter (where stage_cells.core_count is distinct from stage_cells.recount_count)
            || ' stage counts differ from the recount' as detail
    from {{ ref('dim_month') }} as dim_month
    left join stage_cells
        on dim_month.month = stage_cells.month
    group by dim_month.month

),

call_cells as (

    select
        coalesce(core_counts.month, recount.month) as month,
        core_counts.deals_count as core_count,
        recount.deals_count as recount_count
    from (
        select
            fct_activity.due_month as month,
            activity_types.activity_type_name as kpi_name,
            count(distinct fct_activity.deal_id) as deals_count
        from {{ ref('fct_activity') }} as fct_activity
        inner join {{ ref('ods_pipedrive__activity_types') }} as activity_types
            on fct_activity.activity_type = activity_types.activity_type
        where fct_activity.dq_reason is null
            and fct_activity.is_done
            and fct_activity.activity_type in ('meeting', 'sc_2')
        group by 1, 2
    ) as core_counts
    full join ({{ recount_call_steps() }}) as recount
        on core_counts.month = recount.month
        and core_counts.kpi_name = recount.kpi_name

),

call_steps_reconcile as (

    select
        'call_steps_reconcile' as check_name,
        'core' as layer,
        dim_month.month,
        'fail' as severity,
        coalesce(sum(call_cells.recount_count), 0)::numeric as expected_value,
        coalesce(sum(call_cells.core_count), 0)::numeric as actual_value,
        count(*) filter (where call_cells.core_count is distinct from call_cells.recount_count) = 0 as is_passing,
        count(*) filter (where call_cells.core_count is distinct from call_cells.recount_count)
            || ' call counts differ from the recount' as detail
    from {{ ref('dim_month') }} as dim_month
    left join call_cells
        on dim_month.month = call_cells.month
    group by dim_month.month

),

unmapped_stage as (

    select
        'unmapped_stage' as check_name,
        'seed' as layer,
        null::date as month,
        'fail' as severity,
        0::numeric as expected_value,
        count(*)::numeric as actual_value,
        count(*) = 0 as is_passing,
        'Stage rows whose stage has no funnel step' as detail
    from ods_stage_rows
    left join {{ ref('funnel_steps') }} as funnel_steps
        on ods_stage_rows.new_value = funnel_steps.stage_id::text
    where funnel_steps.stage_id is null

),

unmapped_activity_type as (

    select
        'unmapped_activity_type' as check_name,
        'seed' as layer,
        null::date as month,
        'fail' as severity,
        0::numeric as expected_value,
        (unknown_types.activity_rows + unmapped_steps.call_steps)::numeric as actual_value,
        unknown_types.activity_rows + unmapped_steps.call_steps = 0 as is_passing,
        unknown_types.activity_rows || ' activities of an unknown type, '
            || unmapped_steps.call_steps || ' call steps with no activity type' as detail
    from (
        select count(*) as activity_rows
        from {{ ref('ods_pipedrive__activity') }} as activity
        left join {{ ref('ods_pipedrive__activity_types') }} as activity_types
            on activity.activity_type = activity_types.activity_type
        where activity_types.activity_type is null
    ) as unknown_types
    cross join (
        select count(*) as call_steps
        from {{ ref('funnel_steps') }} as funnel_steps
        left join {{ ref('ods_pipedrive__activity_types') }} as activity_types
            on funnel_steps.kpi_name = activity_types.activity_type_name
        where funnel_steps.stage_id is null
            and activity_types.activity_type is null
    ) as unmapped_steps

),

stage_coverage as (

    select
        'stage_coverage' as check_name,
        'ods' as layer,
        monthly_rows.month,
        'warn' as severity,
        null::numeric as expected_value,
        monthly_rows.ods_stage_rows::numeric as actual_value,
        last_observed.observed_on > monthly_rows.month_end as is_passing,
        'Observed stage records until ' || last_observed.observed_on
            || case when last_observed.observed_on > monthly_rows.month_end then '.' else '. Later months may be incomplete.' end as detail
    from monthly_rows
    cross join (select max(changed_at)::date as observed_on from ods_stage_rows) as last_observed

),

activity_coverage as (

    select
        'activity_coverage' as check_name,
        'ods' as layer,
        monthly_rows.month,
        'warn' as severity,
        null::numeric as expected_value,
        monthly_rows.ods_sales_calls::numeric as actual_value,
        last_observed.observed_on > monthly_rows.month_end as is_passing,
        'Observed activity records until ' || last_observed.observed_on
            || case when last_observed.observed_on > monthly_rows.month_end then '.' else '. Later months may be incomplete.' end as detail
    from monthly_rows
    cross join (select max(due_at)::date as observed_on from ods_sales_calls) as last_observed

),

all_checks as (

    select * from raw_tables_loaded
    union all select * from exact_duplicates_in_raw
    union all select * from stage_row_acceptance_rate
    union all select * from sales_call_acceptance_rate
    union all select * from accepted_plus_review_balances
    union all select * from accepted_data_in_every_month
    union all select * from funnel_steps_complete
    union all select * from stage_steps_reconcile
    union all select * from call_steps_reconcile
    union all select * from unmapped_stage
    union all select * from unmapped_activity_type
    union all select * from stage_coverage
    union all select * from activity_coverage

)

select
    check_name,
    layer,
    month,
    severity,
    expected_value,
    actual_value,
    case when coalesce(is_passing, false) then 'pass' else severity end as status,
    detail
from all_checks
order by check_name, month
