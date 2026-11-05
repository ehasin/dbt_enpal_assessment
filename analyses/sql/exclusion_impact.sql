-- Question: what does each exclusion remove, and what does it do to the report?
-- Backs: section 6 of docs/technical_documentation.md.
-- Result on this extract: 102 rows for review, 80 from 5 deals and 22 from 11 activity IDs.
with review as (

    select * from {{ ref('rep_records_for_review') }}

),

sales_calls as (

    select *
    from {{ ref('fct_activity') }}
    where activity_type in ('meeting', 'sc_2')

)

select 'rows for review' as metric, count(*)::text as value from review
union all select 'deal_changes rows excluded', count(*)::text from review where source_table = 'deal_changes'
union all select 'deals excluded', count(distinct deal_id)::text from review where source_table = 'deal_changes'
union all select 'activity rows excluded', count(*)::text from review where source_table = 'activity'
union all select 'activity ids excluded', count(distinct record_id)::text from review where source_table = 'activity'
union all select 'done sales calls excluded', count(*)::text from sales_calls where dq_reason is not null and is_done
union all select 'accepted sales call rows', count(*)::text from sales_calls where dq_reason is null
union all select 'accepted done sales calls', count(*)::text from sales_calls where dq_reason is null and is_done
union all select 'accepted activities with a deal history', count(*)::text from {{ ref('fct_activity') }} where dq_reason is null and has_deal_history
union all select 'accepted done sales calls with a deal history', count(*)::text from sales_calls where dq_reason is null and is_done and has_deal_history
union all select 'report rows', count(*)::text from {{ ref('rep_sales_funnel_monthly') }}
union all select 'report zero rows', count(*)::text from {{ ref('rep_sales_funnel_monthly') }} where deals_count = 0
union all select 'report total', sum(deals_count)::text from {{ ref('rep_sales_funnel_monthly') }}
