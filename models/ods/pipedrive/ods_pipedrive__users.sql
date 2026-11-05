-- Typed users. Emails stop at this layer: no published table holds them.
select distinct
    id as user_id,
    name::text as user_name,
    email::text as email,
    modified as modified_at
from {{ source('pipedrive', 'users') }}
