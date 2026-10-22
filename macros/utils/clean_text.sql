{# Trim + lower-case a free-text code column; empty strings become NULL. #}
{% macro clean_code(column_name) -%}
    nullif(lower(trim({{ column_name }})), '')
{%- endmacro %}
