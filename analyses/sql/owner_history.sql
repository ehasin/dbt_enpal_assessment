-- Question: how many deals changed owner, and did any change fall after a deal's first stage?
-- Backs: the owner limits in docs/technical_documentation.md.
-- Result on this extract: most deals keep one owner, none has more than two, and no owner changes after the first
-- stage, so the last owner also held every stage.
with deal_owners as (

    select
        deal_id,
        count(*) as owner_count,
        max(valid_from) as last_owner_from
    from {{ ref('dim_deal_owner') }}
    group by 1

)

select
    deal_owners.owner_count,
    count(*) as deals,
    count(*) filter (where deal_owners.last_owner_from > dim_deal.first_stage_entered_at) as changed_after_first_stage
from deal_owners
inner join {{ ref('dim_deal') }} as dim_deal
    on deal_owners.deal_id = dim_deal.deal_id
group by 1
order by 1
