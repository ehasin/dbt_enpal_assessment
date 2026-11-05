-- The last owner report: who last owned each deal. Ownership rules stay in dim_deal_owner.
-- depends_on: {{ ref('rep_data_quality_checks') }}
with owner_counts as (

    select
        deal_id,
        count(*) as owner_count
    from {{ ref('dim_deal_owner') }}
    group by 1

)

select
    dim_deal.deal_id,
    dim_deal.owner_user_id,
    dim_user.user_name as owner_name,
    last_owners.valid_from as owner_since,
    coalesce(owner_counts.owner_count, 0)::integer as owner_count,
    dim_stage.kpi_name as current_stage,
    dim_deal.deal_status
from {{ ref('dim_deal') }} as dim_deal
left join {{ ref('dim_deal_owner') }} as last_owners
    on dim_deal.deal_id = last_owners.deal_id
    and last_owners.is_current
left join owner_counts
    on dim_deal.deal_id = owner_counts.deal_id
left join {{ ref('dim_user') }} as dim_user
    on dim_deal.owner_user_id = dim_user.user_id
left join {{ ref('dim_stage') }} as dim_stage
    on dim_deal.current_stage_id = dim_stage.stage_id
order by dim_deal.deal_id
