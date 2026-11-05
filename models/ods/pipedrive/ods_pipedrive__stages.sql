-- Typed pipeline stages, with the source's own spelling.
select distinct
    stage_id,
    stage_name::text as stage_name
from {{ source('pipedrive', 'stages') }}
