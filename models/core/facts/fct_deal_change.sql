-- Every deal field change, with dq_reason set where the deal's identity is broken. Null means accepted.
with deal_changes as (

    select * from {{ ref('ods_pipedrive__deal_changes') }}

),

-- A deal created twice is a broken key, and nothing shows which sequence is right.
deals_created_twice as (

    select deal_id
    from deal_changes
    where changed_field = 'add_time'
    group by deal_id
    having count(*) > 1

)

select
    deal_changes.deal_id,
    deal_changes.changed_field,
    deal_changes.changed_at,
    deal_changes.new_value,
    case
        when deals_created_twice.deal_id is not null then 'multiple_deal_creations'
    end as dq_reason
from deal_changes
left join deals_created_twice
    on deal_changes.deal_id = deals_created_twice.deal_id
