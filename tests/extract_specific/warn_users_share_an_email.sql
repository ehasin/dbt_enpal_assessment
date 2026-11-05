{{ config(severity='warn', tags=['extract_specific']) }}

-- A known oddity of this extract: some users share an email. They stay in, flagged. No report depends on it.
select
    user_id,
    user_name
from {{ ref('dim_user') }}
where has_shared_email
