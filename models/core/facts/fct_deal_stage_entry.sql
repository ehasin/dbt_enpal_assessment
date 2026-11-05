-- One row per deal, stage and entry: the movement logic, including stages a deal skipped.
with stage_moves as (

    select
        deal_id,
        new_value::integer as stage_id,
        changed_at as entered_at,
        -- Rows on one timestamp are ordered by stage, lowest first.
        lag(new_value::integer) over (
            partition by deal_id
            order by changed_at, new_value::integer
        ) as previous_stage_id
    from {{ ref('fct_deal_change') }}
    where changed_field = 'stage_id'
        and dq_reason is null

)

select
    stage_moves.deal_id,
    filled.stage_id,
    stage_moves.entered_at,
    date_trunc('month', stage_moves.entered_at)::date as entered_month,
    filled.stage_id <> stage_moves.stage_id as is_skipped_stage
from stage_moves
-- A forward move enters every stage it passes. A first row, a backward move or a repeat enters only its own.
cross join lateral generate_series(
    case
        when stage_moves.stage_id > stage_moves.previous_stage_id
            then stage_moves.previous_stage_id + 1
        else stage_moves.stage_id
    end,
    stage_moves.stage_id
) as filled(stage_id)
