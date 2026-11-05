-- Question: how long after deal creation is a stage first recorded?
-- Backs: assumption 6 in docs/methodology_and_assumptions.md and the data problems in docs/technical_documentation.md.
-- Result on this extract: a median 35 days to stage 1.
with first_entries as (

    select deal_id, stage_id, min(entered_at) as entered_at
    from {{ ref('fct_deal_stage_entry') }}
    where not is_skipped_stage
    group by 1, 2

)

select
    'median days from creation to stage ' || first_entries.stage_id as metric,
    percentile_cont(0.5) within group (
        order by first_entries.entered_at::date - dim_deal.deal_created_at::date
    )::text as value
from first_entries
inner join {{ ref('dim_deal') }} as dim_deal
    on first_entries.deal_id = dim_deal.deal_id
where first_entries.stage_id <= 3
group by first_entries.stage_id

union all

select 'deals with stage 1 later than creation', count(*)::text
from {{ ref('dim_deal') }}
where first_stage_entered_at > deal_created_at

union all

select 'deals with stage 1 in a later month than creation', count(*)::text
from {{ ref('dim_deal') }}
where date_trunc('month', first_stage_entered_at) > date_trunc('month', deal_created_at)

union all

select 'deal month ends with no stage yet', count(*)::text
from {{ ref('dim_deal') }} as dim_deal
cross join {{ ref('dim_month') }} as dim_month
where dim_deal.deal_created_at::date <= dim_month.month_end
    and dim_deal.first_stage_entered_at::date > dim_month.month_end
    and (dim_deal.lost_at is null or dim_deal.lost_at::date > dim_month.month_end)

order by metric
