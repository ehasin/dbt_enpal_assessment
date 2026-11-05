-- Question: can a call be tied to a deal? Joins deal_id, then activity_id, to the deal IDs, against what shuffled IDs
-- would give: IDs on one side * IDs on the other / size of the shared ID range.
-- Backs: the key assumption in docs/methodology_and_assumptions.md.
-- Result on this extract: 8 deal ID matches against 10 expected from shuffled IDs: too sparse to rely on.
with deal_ids as (

    select distinct deal_id from {{ source('pipedrive', 'deal_changes') }}

),

call_deal_ids as (

    select distinct deal_id from {{ source('pipedrive', 'activity') }}

),

activity_ids as (

    select distinct activity_id from {{ source('pipedrive', 'activity') }}

),

id_range as (

    select
        min(id) as lowest_id,
        max(id) as highest_id,
        (max(id) - min(id) + 1)::numeric as id_space
    from (
        select deal_id as id from deal_ids
        union all select deal_id from call_deal_ids
        union all select activity_id from activity_ids
    ) as ids

),

overlap_calls as (

    select
        activity.activity_id,
        activity.due_to,
        creation.created_at
    from {{ source('pipedrive', 'activity') }} as activity
    inner join (
        select deal_id, min(change_time) as created_at
        from {{ source('pipedrive', 'deal_changes') }}
        where changed_field_key = 'add_time'
        group by 1
    ) as creation
        on activity.deal_id = creation.deal_id

)

select 'deal ids in deal_changes' as metric, count(*)::text as value from deal_ids
union all select 'deal ids in activity', count(*)::text from call_deal_ids
union all select 'lowest id in any source', lowest_id::text from id_range
union all select 'highest id in any source', highest_id::text from id_range
union all select 'deal_id matches', count(*)::text from call_deal_ids inner join deal_ids using (deal_id)
union all select 'deal_id matches by chance', round((select count(*) from call_deal_ids) * (select count(*) from deal_ids) / id_space, 1)::text from id_range
union all select 'activity_id matches', count(*)::text from activity_ids inner join deal_ids on activity_ids.activity_id = deal_ids.deal_id
union all select 'activity_id matches by chance', round((select count(*) from activity_ids) * (select count(*) from deal_ids) / id_space, 1)::text from id_range
union all select 'linked calls', count(*)::text from overlap_calls
union all select 'linked calls due before the deal was created', count(*)::text from overlap_calls where due_to < created_at
