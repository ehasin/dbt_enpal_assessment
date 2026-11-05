{{ config(severity='warn', tags=['extract_specific']) }}

-- A known oddity of this extract: a stage name differs from the required label. The report uses the required label.
select
    stage_id,
    source_stage_name,
    kpi_name
from {{ ref('dim_stage') }}
where source_stage_name <> kpi_name
