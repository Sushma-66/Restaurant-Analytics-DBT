{#
    Environment-aware schema naming.

    * prod  -> use the custom schema as-is            (core, finance, marketing ...)
    * other -> prefix with the target schema         (dev_sushma_core, ci_core ...)

    This keeps every developer's work isolated while prod gets clean names.
#}
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- set default_schema = target.schema -%}
    {%- if custom_schema_name is none -%}
        {{ default_schema }}
    {%- elif target.name == 'prod' -%}
        {{ custom_schema_name | trim }}
    {%- else -%}
        {{ default_schema }}_{{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}
