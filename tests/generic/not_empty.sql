{# Fails when the table has no rows: an empty table passes every column test. #}
{% test not_empty(model) %}

select 'no rows' as problem
where not exists (select 1 from {{ model }})

{% endtest %}
