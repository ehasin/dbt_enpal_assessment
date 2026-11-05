{# Independent recounts for the output comparison. They read ods_ only, with no core model or seed,
   and use a different method from core, so a fault in core or a report can't hide here. #}

{% macro recount_months() %}
    select generate_series(
        date_trunc('month', min(observed_at)),
        date_trunc('month', max(observed_at)),
        interval '1 month'
    )::date as month
    from (
        select changed_at as observed_at from {{ ref('ods_pipedrive__deal_changes') }} where changed_field = 'stage_id'
        union all
        select due_at from {{ ref('ods_pipedrive__activity') }}
    ) as observed_dates
{% endmacro %}

{% macro recount_accepted_deal_changes() %}
    select *
    from {{ ref('ods_pipedrive__deal_changes') }}
    where deal_id not in (
        select deal_id
        from {{ ref('ods_pipedrive__deal_changes') }}
        where changed_field = 'add_time'
        group by deal_id
        having count(*) > 1
    )
{% endmacro %}

{# Entries per month and stage: a self-join on row order and a range join on the stage list. #}
{% macro recount_stage_entries() %}
    with stage_rows as (

        select
            deal_id,
            changed_at,
            new_value::integer as stage_id,
            row_number() over (partition by deal_id order by changed_at, new_value::integer) as row_order
        from ({{ recount_accepted_deal_changes() }}) as accepted_deal_changes
        where changed_field = 'stage_id'

    )

    select
        date_trunc('month', stage_row.changed_at)::date as month,
        stages.stage_id,
        count(distinct stage_row.deal_id) as deals_count
    from stage_rows as stage_row
    left join stage_rows as previous_row
        on stage_row.deal_id = previous_row.deal_id
        and stage_row.row_order = previous_row.row_order + 1
    inner join {{ ref('ods_pipedrive__stages') }} as stages
        on stages.stage_id = stage_row.stage_id
        or (stages.stage_id > previous_row.stage_id and stages.stage_id < stage_row.stage_id)
    group by 1, 2
{% endmacro %}

{# Done sales calls per month and call name, leaving out repeated activity IDs. #}
{% macro recount_call_steps() %}
    select
        date_trunc('month', activity.due_at)::date as month,
        activity_types.activity_type_name as kpi_name,
        count(distinct activity.deal_id) as deals_count
    from {{ ref('ods_pipedrive__activity') }} as activity
    inner join {{ ref('ods_pipedrive__activity_types') }} as activity_types
        on activity.activity_type = activity_types.activity_type
    where activity.is_done
        and activity_types.activity_type_name like 'Sales Call %'
        and activity.activity_id not in (
            select activity_id
            from {{ ref('ods_pipedrive__activity') }}
            group by activity_id
            having count(*) > 1
        )
    group by 1, 2
{% endmacro %}

{# Open deals per month end and stage: the latest stage row at each month end, unless a lost reason came first. #}
{% macro recount_stage_distribution() %}
    with accepted_deal_changes as (

        {{ recount_accepted_deal_changes() }}

    ),

    latest_stage_rows as (

        select distinct on (months.month, stage_rows.deal_id)
            months.month,
            stage_rows.deal_id,
            stage_rows.new_value::integer as stage_id
        from ({{ recount_months() }}) as months
        inner join accepted_deal_changes as stage_rows
            on stage_rows.changed_field = 'stage_id'
            and stage_rows.changed_at < months.month + interval '1 month'
        order by months.month, stage_rows.deal_id, stage_rows.changed_at desc, stage_rows.new_value::integer desc

    )

    select
        latest_stage_rows.month,
        latest_stage_rows.stage_id,
        count(*) as deals_count
    from latest_stage_rows
    where not exists (
        select 1
        from accepted_deal_changes as lost_rows
        where lost_rows.deal_id = latest_stage_rows.deal_id
            and lost_rows.changed_field = 'lost_reason'
            and lost_rows.changed_at < latest_stage_rows.month + interval '1 month'
    )
    group by 1, 2
{% endmacro %}
