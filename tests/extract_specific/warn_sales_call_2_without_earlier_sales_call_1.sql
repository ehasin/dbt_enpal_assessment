{{ config(severity='warn', tags=['extract_specific']) }}

-- A known oddity of this extract: Sales Call 2 rows have no earlier Sales Call 1 on their deal ID.
-- They stay in, and each call step counts on its own.
with accepted_calls as (

    select
        activity_id,
        deal_id,
        activity_type,
        due_at
    from {{ ref('fct_activity') }}
    where dq_reason is null

)

select
    second_call.activity_id,
    second_call.deal_id,
    second_call.due_at
from accepted_calls as second_call
left join accepted_calls as first_call
    on second_call.deal_id = first_call.deal_id
    and first_call.activity_type = 'meeting'
    and first_call.due_at < second_call.due_at
where second_call.activity_type = 'sc_2'
    and first_call.activity_id is null
