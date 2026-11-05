-- Question: does the user ID tie a done sales call to a deal? Counts calls whose user owned a deal that sat in the
-- matching stage on the call's date, or entered that stage within 7 days of it. Shuffle 0 is the real assignment.
-- Shuffles 1-20 hand the same users to the calls in a fixed pseudo-random order.
-- Backs: the key assumption in docs/methodology_and_assumptions.md.
-- Result on this extract: real users sit inside the range of shuffled users, so users show no link either.
with owners as (

    select distinct deal_id, new_value::integer as user_id
    from {{ source('pipedrive', 'deal_changes') }}
    where changed_field_key = 'user_id'

),

stage_entries as (

    select deal_id, new_value::integer as stage_id, min(change_time) as entered_at
    from {{ source('pipedrive', 'deal_changes') }}
    where changed_field_key = 'stage_id'
    group by 1, 2

),

stage_windows as (

    select
        deal_id,
        stage_id,
        entered_at,
        coalesce(lead(entered_at) over (partition by deal_id order by entered_at), 'infinity'::timestamp) as left_at
    from stage_entries

),

owned_windows as (

    select
        owners.user_id,
        stage_windows.stage_id,
        stage_windows.entered_at,
        stage_windows.left_at
    from stage_windows
    inner join owners on stage_windows.deal_id = owners.deal_id

),

sales_calls as (

    select
        row_number() over (order by activity_id, due_to) as call_number,
        activity_id,
        due_to,
        assigned_to_user,
        case type when 'meeting' then 2 else 3 end as stage_id
    from {{ source('pipedrive', 'activity') }}
    where done and type in ('meeting', 'sc_2')

),

shuffled_users as (

    select
        shuffle,
        row_number() over (
            partition by shuffle
            order by case when shuffle = 0 then lpad(call_number::text, 32, '0') else md5(shuffle || '-' || activity_id || '-' || due_to) end
        ) as call_number,
        assigned_to_user as user_id
    from sales_calls
    cross join generate_series(0, 20) as shuffle

),

calls_by_shuffle as (

    select
        shuffled_users.shuffle,
        shuffled_users.user_id,
        sales_calls.call_number,
        sales_calls.stage_id,
        sales_calls.due_to
    from shuffled_users
    inner join sales_calls on shuffled_users.call_number = sales_calls.call_number

),

matches as (

    select
        calls_by_shuffle.shuffle,
        count(distinct calls_by_shuffle.call_number) filter (
            where calls_by_shuffle.due_to >= owned_windows.entered_at
                and calls_by_shuffle.due_to < owned_windows.left_at
        ) as in_stage,
        count(distinct calls_by_shuffle.call_number) filter (
            where calls_by_shuffle.due_to between owned_windows.entered_at - interval '7 days'
                and owned_windows.entered_at + interval '7 days'
        ) as within_7_days
    from calls_by_shuffle
    inner join owned_windows
        on calls_by_shuffle.user_id = owned_windows.user_id
        and calls_by_shuffle.stage_id = owned_windows.stage_id
    group by 1

),

deals_per_user as (

    select new_value::integer as user_id, count(distinct deal_id) as deals
    from {{ source('pipedrive', 'deal_changes') }}
    where changed_field_key = 'user_id'
    group by 1

),

calls_per_user as (

    select assigned_to_user as user_id, count(*) as calls
    from {{ source('pipedrive', 'activity') }}
    group by 1

)

select 'done sales calls' as metric, count(*)::text as value from sales_calls
union all select 'real users, in stage', in_stage::text from matches where shuffle = 0
union all select 'shuffled users, in stage, lowest', min(in_stage)::text from matches where shuffle > 0
union all select 'shuffled users, in stage, highest', max(in_stage)::text from matches where shuffle > 0
union all select 'real users, within 7 days', within_7_days::text from matches where shuffle = 0
union all select 'shuffled users, within 7 days, lowest', min(within_7_days)::text from matches where shuffle > 0
union all select 'shuffled users, within 7 days, highest', max(within_7_days)::text from matches where shuffle > 0
union all
select 'correlation of deals owned and calls per user', round(corr(coalesce(deals, 0), coalesce(calls, 0))::numeric, 2)::text
from (select id as user_id from {{ source('pipedrive', 'users') }}) as users
left join deals_per_user using (user_id)
left join calls_per_user using (user_id)
