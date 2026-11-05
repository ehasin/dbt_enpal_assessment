{# Fails on any repeated combination of the given columns: the grain test for a composite key. #}
{% test unique_combination(model, columns) %}

select {{ columns | join(', ') }}
from {{ model }}
group by {{ columns | join(', ') }}
having count(*) > 1

{% endtest %}
