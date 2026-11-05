-- Every activity, with dq_reason set where its ID is broken. Null means accepted.
with activities as (

    select * from {{ ref('ods_pipedrive__activity') }}

),

-- A repeated ID is a broken key: the rows differ, and nothing shows which is right.
repeated_activity_ids as (

    select activity_id
    from activities
    group by activity_id
    having count(*) > 1

)

select
    activities.activity_id,
    activities.activity_type,
    activities.assigned_user_id,
    activities.deal_id,
    activities.is_done,
    activities.due_at,
    date_trunc('month', activities.due_at)::date as due_month,
    -- Information only. Calls count without a join to deals, whether this is true or not.
    dim_deal.deal_id is not null as has_deal_history,
    case
        when repeated_activity_ids.activity_id is not null then 'duplicate_activity_id'
    end as dq_reason
from activities
left join repeated_activity_ids
    on activities.activity_id = repeated_activity_ids.activity_id
left join {{ ref('dim_deal') }} as dim_deal
    on activities.deal_id = dim_deal.deal_id
