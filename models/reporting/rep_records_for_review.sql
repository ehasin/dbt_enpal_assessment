-- Every row kept out of accepted data, with its reason, to clear with the source owner.
with flagged_deal_changes as (

    select
        'deal_changes' as source_table,
        null::integer as record_id,
        deal_id,
        dq_reason,
        to_jsonb(fct_deal_change) - 'dq_reason' as source_record
    from {{ ref('fct_deal_change') }} as fct_deal_change
    where dq_reason is not null

),

flagged_activities as (

    select
        'activity' as source_table,
        activity_id as record_id,
        deal_id,
        dq_reason,
        to_jsonb(fct_activity) - array['dq_reason', 'due_month', 'has_deal_history']::text[] as source_record
    from {{ ref('fct_activity') }} as fct_activity
    where dq_reason is not null

),

flagged_records as (

    select * from flagged_deal_changes
    union all
    select * from flagged_activities

)

select
    source_table,
    -- activity_id repeats here and deal_changes has no ID, so the whole row is the locator.
    md5(source_table || source_record::text) as record_key,
    record_id,
    deal_id,
    dq_reason,
    source_record
from flagged_records
