{#
    UK restaurant prices are VAT-inclusive. Back out the VAT element:
        net = gross / (1 + rate),   vat = gross - net
#}
{% macro net_of_vat(amount, rate=var('vat_rate')) -%}
    cast(round({{ amount }} / (1 + {{ rate }}), 2) as decimal(12, 2))
{%- endmacro %}

{% macro vat_amount(amount, rate=var('vat_rate')) -%}
    cast(round({{ amount }} - ({{ amount }} / (1 + {{ rate }})), 2) as decimal(12, 2))
{%- endmacro %}
