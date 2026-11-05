-- Typed deal fields, the source of lost reason labels.
select distinct
    id as field_id,
    field_key::text as field_key,
    name::text as field_name,
    field_value_options
from {{ source('pipedrive', 'fields') }}
