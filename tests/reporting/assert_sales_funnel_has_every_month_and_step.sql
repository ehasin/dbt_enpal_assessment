-- The report's shape: one row for every month and every step, so a missing cell can't pass as a zero.
with expected_rows as (

    select
        (select count(*) from {{ ref('dim_month') }})
        * (select count(*) from {{ ref('funnel_steps') }}) as row_count

),

actual_rows as (

    select count(*) as row_count
    from {{ ref('rep_sales_funnel_monthly') }}

)

select
    expected_rows.row_count as expected_row_count,
    actual_rows.row_count as actual_row_count
from expected_rows
cross join actual_rows
where expected_rows.row_count <> actual_rows.row_count
