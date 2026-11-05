-- One row per reporting month. Reads ods_, not accepted data, so losing every row can't empty the calendar.
with observed_dates as (

    select changed_at as observed_at
    from {{ ref('ods_pipedrive__deal_changes') }}
    where changed_field = 'stage_id'

    union all

    select due_at
    from {{ ref('ods_pipedrive__activity') }}

),

month_range as (

    select
        date_trunc('month', min(observed_at)) as first_month,
        date_trunc('month', max(observed_at)) as last_month
    from observed_dates

)

select
    month_start::date as month,
    (month_start + interval '1 month - 1 day')::date as month_end
from month_range
cross join lateral generate_series(first_month, last_month, interval '1 month') as month_start
