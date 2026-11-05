-- Question: how many deals, stage rows and calls does each month hold, on the raw sources?
-- Backs: the coverage statements in docs/technical_documentation.md.
-- Result on this extract: activities stop in September 2024, stage rows in February 2025.
with months as (

    select date_trunc('month', change_time)::date as month from {{ source('pipedrive', 'deal_changes') }}
    union
    select date_trunc('month', due_to)::date from {{ source('pipedrive', 'activity') }}

),

deal_rows as (

    select
        date_trunc('month', change_time)::date as month,
        count(*) filter (where changed_field_key = 'add_time') as deals_created,
        count(*) filter (where changed_field_key = 'stage_id') as stage_rows,
        count(*) filter (where changed_field_key = 'lost_reason') as lost_reasons
    from {{ source('pipedrive', 'deal_changes') }}
    group by 1

),

call_rows as (

    select
        date_trunc('month', due_to)::date as month,
        count(*) as calls,
        count(*) filter (where done and type in ('meeting', 'sc_2')) as done_sales_calls
    from {{ source('pipedrive', 'activity') }}
    group by 1

)

select
    months.month,
    coalesce(deal_rows.deals_created, 0) as deals_created,
    coalesce(deal_rows.stage_rows, 0) as stage_rows,
    coalesce(deal_rows.lost_reasons, 0) as lost_reasons,
    coalesce(call_rows.calls, 0) as calls,
    coalesce(call_rows.done_sales_calls, 0) as done_sales_calls
from months
left join deal_rows on months.month = deal_rows.month
left join call_rows on months.month = call_rows.month
order by months.month
