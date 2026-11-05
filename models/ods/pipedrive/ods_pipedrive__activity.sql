-- Typed, deduplicated activities. One row per activity row in the source.
select distinct
    activity_id,
    type::text as activity_type,
    assigned_to_user as assigned_user_id,
    deal_id,
    done as is_done,
    due_to as due_at
from {{ source('pipedrive', 'activity') }}
