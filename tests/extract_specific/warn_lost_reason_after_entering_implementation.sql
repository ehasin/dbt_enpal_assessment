{{ config(severity='warn', tags=['extract_specific']) }}

-- A known oddity of this extract: deals get a lost reason after they entered Implementation.
-- They stay in. Compares the two events, not just whether a high stage was ever reached.
with implementation_entries as (

    select
        deal_id,
        min(entered_at) as entered_implementation_at
    from {{ ref('fct_deal_stage_entry') }}
    where stage_id = 7
    group by deal_id

)

select
    dim_deal.deal_id,
    implementation_entries.entered_implementation_at,
    dim_deal.lost_at
from {{ ref('dim_deal') }} as dim_deal
inner join implementation_entries
    on dim_deal.deal_id = implementation_entries.deal_id
where dim_deal.lost_at >= implementation_entries.entered_implementation_at
