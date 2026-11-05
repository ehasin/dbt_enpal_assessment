-- One row per user, without emails. A shared email is a flag only: it doesn't affect any report.
with users as (

    select
        *,
        count(*) over (partition by lower(trim(email))) as users_with_this_email
    from {{ ref('ods_pipedrive__users') }}

)

select
    user_id,
    user_name,
    users_with_this_email > 1 as has_shared_email,
    modified_at
from users
