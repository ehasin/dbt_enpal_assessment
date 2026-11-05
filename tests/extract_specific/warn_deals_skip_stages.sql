{{ config(severity='warn', tags=['extract_specific']) }}

-- A known oddity of this extract: deals skip stages. They stay in, and count in the stages they passed.
select
    deal_id,
    stage_id,
    entered_at
from {{ ref('fct_deal_stage_entry') }}
where is_skipped_stage
