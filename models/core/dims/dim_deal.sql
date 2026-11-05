-- One row per accepted deal: pivots the key/value change log into the business view of a deal.
with deal_changes as (

    select * from {{ ref('fct_deal_change') }}
    where dq_reason is null

),

deal_attributes as (

    select
        deal_id,
        min(changed_at) filter (where changed_field = 'add_time') as deal_created_at,
        min(changed_at) filter (where changed_field = 'stage_id') as first_stage_entered_at,
        (array_agg(new_value::integer order by changed_at desc, new_value::integer desc)
            filter (where changed_field = 'stage_id'))[1] as current_stage_id,
        max(new_value::integer) filter (where changed_field = 'stage_id') as max_stage_id,
        -- The extract has no status history, so the earliest lost reason stands in for the loss time.
        min(changed_at) filter (where changed_field = 'lost_reason') as lost_at,
        (array_agg(new_value order by changed_at)
            filter (where changed_field = 'lost_reason'))[1] as lost_reason_id
    from deal_changes
    group by deal_id

),

lost_reason_labels as (

    select
        lost_reason_option ->> 'id' as lost_reason_id,
        lost_reason_option ->> 'label' as lost_reason
    from {{ ref('ods_pipedrive__fields') }}
    cross join lateral jsonb_array_elements(field_value_options) as lost_reason_option
    where field_key = 'lost_reason'

)

select
    deal_attributes.deal_id,
    deal_attributes.deal_created_at,
    deal_attributes.first_stage_entered_at,
    deal_attributes.current_stage_id,
    deal_attributes.max_stage_id,
    current_owners.owner_user_id,
    -- An estimate: the extract has no deal status, only lost reasons.
    case when deal_attributes.lost_at is null then 'open' else 'lost' end as deal_status,
    deal_attributes.lost_at,
    deal_attributes.lost_reason_id::integer as lost_reason_id,
    lost_reason_labels.lost_reason
from deal_attributes
left join lost_reason_labels
    on deal_attributes.lost_reason_id = lost_reason_labels.lost_reason_id
left join {{ ref('dim_deal_owner') }} as current_owners
    on deal_attributes.deal_id = current_owners.deal_id
    and current_owners.is_current
