-- Question: how often do deals skip stages, move backward, or get a lost reason after Implementation?
-- Backs: the appendix of docs/methodology_and_assumptions.md and section 6 of docs/technical_documentation.md.
-- Result on this extract: 2,502 of 6,911 raw moves skip a stage. All 10 backward or repeated moves sit on excluded deals.
with moves as (

    select
        'accepted' as dataset,
        deal_id,
        new_value::integer as to_stage,
        lag(new_value::integer) over (partition by deal_id order by changed_at, new_value::integer) as from_stage
    from {{ ref('fct_deal_change') }}
    where changed_field = 'stage_id'
        and dq_reason is null

    union all

    select
        'raw',
        deal_id,
        new_value::integer,
        lag(new_value::integer) over (partition by deal_id order by changed_at, new_value::integer)
    from {{ ref('ods_pipedrive__deal_changes') }}
    where changed_field = 'stage_id'

),

lost_after_implementation as (

    select distinct dim_deal.deal_id
    from {{ ref('dim_deal') }} as dim_deal
    inner join {{ ref('fct_deal_stage_entry') }} as entries
        on dim_deal.deal_id = entries.deal_id
        and entries.stage_id = 7
    where dim_deal.lost_at >= entries.entered_at

),

sales_calls as (

    select *
    from {{ ref('fct_activity') }}
    where dq_reason is null
        and activity_type in ('meeting', 'sc_2')

),

sales_call_order as (

    select
        second_call.activity_id,
        exists (
            select 1
            from sales_calls as first_call
            where first_call.deal_id = second_call.deal_id
                and first_call.activity_type = 'meeting'
                and first_call.due_at < second_call.due_at
        ) as has_earlier_call_1
    from sales_calls as second_call
    where second_call.activity_type = 'sc_2'

)

select dataset || ' stage moves' as metric, count(*)::text as value from moves where from_stage is not null group by dataset
union all select dataset || ' skipped moves', count(*)::text from moves where to_stage > from_stage + 1 group by dataset
union all select dataset || ' deals with a skipped move', count(distinct deal_id)::text from moves where to_stage > from_stage + 1 group by dataset
union all select dataset || ' backward or repeated moves', count(*)::text from moves where to_stage <= from_stage group by dataset
union all select 'accepted deals', count(*)::text from {{ ref('dim_deal') }}
union all select 'accepted deals with a lost reason', count(*)::text from {{ ref('dim_deal') }} where deal_status = 'lost'
union all select 'deals lost after entering Implementation', count(*)::text from lost_after_implementation
union all select 'lost reason: ' || lost_reason, count(*)::text from {{ ref('dim_deal') }} group by lost_reason
union all select 'Sales Call 2 rows', count(*)::text from sales_call_order
union all select 'Sales Call 2 rows with no earlier Sales Call 1', count(*)::text from sales_call_order where not has_earlier_call_1
