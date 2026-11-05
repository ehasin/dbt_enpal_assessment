-- One row per accepted deal and period of ownership: the history behind `owner_user_id` in dim_deal.
-- Built from the change log, which keeps every owner, so no dbt snapshot is needed.
with owner_changes as (

    select distinct on (deal_id, changed_at)
        deal_id,
        changed_at,
        new_value::integer as owner_user_id
    from {{ ref('fct_deal_change') }}
    where dq_reason is null
        and changed_field = 'user_id'
    -- Owner rows on one timestamp leave the highest ID, as tied stage rows do.
    order by deal_id, changed_at, new_value::integer desc

),

owner_starts as (

    select
        *,
        lag(owner_user_id) over (partition by deal_id order by changed_at) as previous_owner_user_id
    from owner_changes

)

select
    deal_id,
    owner_user_id,
    changed_at as valid_from,
    lead(changed_at) over deal_periods as valid_to,
    lead(changed_at) over deal_periods is null as is_current
from owner_starts
where owner_user_id is distinct from previous_owner_user_id
window deal_periods as (partition by deal_id order by changed_at)
