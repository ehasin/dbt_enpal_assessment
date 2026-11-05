-- Typed activity types: the source's own mapping of meeting to Sales Call 1.
select distinct
    id as activity_type_id,
    name::text as activity_type_name,
    active = 'Yes' as is_active,
    type::text as activity_type
from {{ source('pipedrive', 'activity_types') }}
