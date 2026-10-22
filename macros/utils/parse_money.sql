{#
    Converts POS money strings ('£1,234.50', ' £0.00 ', '') to DECIMAL(12,2).
    Empty / unparseable values become NULL rather than failing the run,
    and are caught downstream by not_null tests where they matter.
#}
{% macro parse_money(column_name) -%}
    try_cast(
        nullif(trim(replace(replace({{ column_name }}, '£', ''), ',', '')), '')
        as decimal(12, 2)
    )
{%- endmacro %}
