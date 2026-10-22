{#
    Generic test: the sum of `column_name` in the child model, grouped by
    `join_key`, must equal `parent_column` in `parent_model` within a tolerance.

    Used to prove payments taken == order totals (the same reconciliation a
    restaurant manager does manually at end of day).
#}
{% test amounts_reconcile(model, column_name, join_key, parent_model, parent_column, tolerance=0.01, parent_where='1=1') %}

with child as (
    select {{ join_key }} as k, sum({{ column_name }}) as child_total
    from {{ model }}
    group by 1
),

parent as (
    select {{ join_key }} as k, {{ parent_column }} as parent_total
    from {{ parent_model }}
    where {{ parent_where }}
)

select
    parent.k,
    parent.parent_total,
    coalesce(child.child_total, 0) as child_total,
    parent.parent_total - coalesce(child.child_total, 0) as difference
from parent
left join child on parent.k = child.k
where abs(parent.parent_total - coalesce(child.child_total, 0)) > {{ tolerance }}

{% endtest %}
