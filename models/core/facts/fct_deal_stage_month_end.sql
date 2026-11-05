-- One row per open deal and month end: the position logic. A deal is open until it gets a lost reason.
with stage_positions as (

    -- A deal sits only in stages it was recorded in. A skipped stage is passed, never held.
    select
        deal_id,
        stage_id,
        entered_at,
        lead(entered_at) over (partition by deal_id order by entered_at, stage_id) as left_at
    from {{ ref('fct_deal_stage_entry') }}
    where not is_skipped_stage

)

select
    stage_positions.deal_id,
    dim_month.month,
    stage_positions.stage_id
from stage_positions
inner join {{ ref('dim_month') }} as dim_month
    on stage_positions.entered_at::date <= dim_month.month_end
    and (stage_positions.left_at is null or stage_positions.left_at::date > dim_month.month_end)
inner join {{ ref('dim_deal') }} as dim_deal
    on stage_positions.deal_id = dim_deal.deal_id
where dim_deal.lost_at is null
    or dim_deal.lost_at::date > dim_month.month_end
