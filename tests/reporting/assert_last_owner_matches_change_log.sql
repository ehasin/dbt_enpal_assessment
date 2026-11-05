-- Rebuilds every column of the last owner report from ods_, with no core model, and compares every deal.
-- Runs after the report builds, so a failure flags a wrong report rather than holding it back.
with accepted_deal_changes as (

    {{ recount_accepted_deal_changes() }}

),

deals as (

    select
        deal_id,
        bool_or(changed_field = 'lost_reason') as has_lost_reason
    from accepted_deal_changes
    group by 1

),

owner_rows as (

    select
        deal_id,
        changed_at,
        max(new_value::integer) as owner_user_id,
        row_number() over (partition by deal_id order by changed_at) as row_order
    from accepted_deal_changes
    where changed_field = 'user_id'
    group by 1, 2

),

owner_periods as (

    select owner_row.*
    from owner_rows as owner_row
    left join owner_rows as previous_row
        on owner_row.deal_id = previous_row.deal_id
        and owner_row.row_order = previous_row.row_order + 1
    where owner_row.owner_user_id is distinct from previous_row.owner_user_id

),

last_owners as (

    select distinct on (deal_id)
        deal_id,
        owner_user_id,
        changed_at as owner_since,
        count(*) over (partition by deal_id) as owner_count
    from owner_periods
    order by deal_id, changed_at desc

),

last_stages as (

    select distinct on (deal_id)
        deal_id,
        new_value::integer as stage_id
    from accepted_deal_changes
    where changed_field = 'stage_id'
    order by deal_id, changed_at desc, new_value::integer desc

),

expected_rows as (

    select
        deals.deal_id,
        last_owners.owner_user_id,
        users.user_name as owner_name,
        last_owners.owner_since,
        coalesce(last_owners.owner_count, 0)::integer as owner_count,
        lower(stages.stage_name) as current_stage,
        case when deals.has_lost_reason then 'lost' else 'open' end as deal_status
    from deals
    left join last_owners
        on deals.deal_id = last_owners.deal_id
    left join {{ ref('ods_pipedrive__users') }} as users
        on last_owners.owner_user_id = users.user_id
    left join last_stages
        on deals.deal_id = last_stages.deal_id
    left join {{ ref('ods_pipedrive__stages') }} as stages
        on last_stages.stage_id = stages.stage_id

),

report_rows as (

    select
        deal_id,
        owner_user_id,
        owner_name,
        owner_since,
        owner_count,
        lower(current_stage) as current_stage,
        deal_status
    from {{ ref('rep_deal_last_owner') }}

)

select
    coalesce(report_rows.deal_id, expected_rows.deal_id) as deal_id,
    report_rows::text as report_row,
    expected_rows::text as change_log_row
from report_rows
full join expected_rows
    on report_rows.deal_id = expected_rows.deal_id
where report_rows is distinct from expected_rows
