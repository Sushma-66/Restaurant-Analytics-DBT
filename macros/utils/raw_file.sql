{#
    Path to a landing-zone file. Centralised so CI / prod can repoint the
    landing zone with --vars '{raw_data_path: s3://bucket/landing}'.
#}
{% macro raw_file(file_name) -%}
    {{ var('raw_data_path') }}/{{ file_name }}
{%- endmacro %}
