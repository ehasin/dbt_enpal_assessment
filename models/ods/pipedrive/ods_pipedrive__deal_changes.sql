-- Typed, deduplicated log of deal field changes, in key/value form. One row per recorded change.
select distinct
    deal_id,
    change_time as changed_at,
    changed_field_key::text as changed_field,
    new_value::text as new_value
from {{ source('pipedrive', 'deal_changes') }}
