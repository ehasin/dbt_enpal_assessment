-- Question: how big is each raw source, what do its keys look like, and what dates does it cover?
-- Backs: the source profile in docs/technical_documentation.md.
-- Result on this extract: 15,406 deal changes, 4,579 activities, 1,787 users.
with deal_changes as (

    select * from {{ source('pipedrive', 'deal_changes') }}

),

activity as (

    select * from {{ source('pipedrive', 'activity') }}

),

users as (

    select * from {{ source('pipedrive', 'users') }}

),

calls_per_deal as (

    select
        deal_id,
        count(*) as calls,
        count(*) filter (where type = 'meeting') as sales_call_1,
        count(*) filter (where type = 'sc_2') as sales_call_2
    from activity
    group by 1

)

select 'deal_changes rows' as metric, count(*)::text as value from deal_changes
union all select 'deal_changes deals', count(distinct deal_id)::text from deal_changes
union all select 'deal_changes first date', min(change_time)::date::text from deal_changes
union all select 'deal_changes last date', max(change_time)::date::text from deal_changes
union all select 'deal_changes stage rows', count(*)::text from deal_changes where changed_field_key = 'stage_id'
union all select 'first stage row', min(change_time)::date::text from deal_changes where changed_field_key = 'stage_id'
union all select 'last stage row', max(change_time)::date::text from deal_changes where changed_field_key = 'stage_id'
union all select 'last deal creation', max(change_time)::date::text from deal_changes where changed_field_key = 'add_time'
union all select 'last lost reason', max(change_time)::date::text from deal_changes where changed_field_key = 'lost_reason'
union all select 'activity rows', count(*)::text from activity
union all select 'activity distinct ids', count(distinct activity_id)::text from activity
union all select 'activity distinct deal ids', count(distinct deal_id)::text from activity
union all select 'activity first due date', min(due_to)::date::text from activity
union all select 'activity last due date', max(due_to)::date::text from activity
union all select 'users rows', count(*)::text from users
union all select 'users first modified', min(modified)::date::text from users
union all select 'users last modified', max(modified)::date::text from users
union all select 'stages rows', count(*)::text from {{ source('pipedrive', 'stages') }}
union all select 'activity_types rows', count(*)::text from {{ source('pipedrive', 'activity_types') }}
union all select 'fields rows', count(*)::text from {{ source('pipedrive', 'fields') }}
union all select 'deal ids with one call', count(*)::text from calls_per_deal where calls = 1
union all select 'deal ids with two calls', count(*)::text from calls_per_deal where calls = 2
union all select 'deal ids with both sales calls', count(*)::text from calls_per_deal where sales_call_1 > 0 and sales_call_2 > 0
union all select 'deal ids with two of one sales call', count(*)::text from calls_per_deal where sales_call_1 > 1 or sales_call_2 > 1
