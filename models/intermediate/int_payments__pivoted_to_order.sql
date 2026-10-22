{%- set payment_groups = ['electronic', 'cash', 'stored_value', 'third_party'] -%}

with payments as (

    select * from {{ ref('stg_pos__payments') }}

)

select
    order_id,
    count(*)                                            as payment_count,
    sum(amount)                                         as total_paid,
    sum(tip_amount)                                     as total_tips,
    {% for group in payment_groups -%}
    sum(case when payment_group = '{{ group }}' then amount else 0 end)
                                                        as paid_{{ group }}{{ "," if not loop.last }}
    {% endfor %}
from payments
group by 1
