{#
    Grain: one row per branch per trading day.
    Compares what was rung through the till with what was actually tendered.
    Any non-zero variance is a cash-up discrepancy to investigate.
#}

with orders as (

    select * from {{ ref('fct_orders') }}
    where order_status in ('completed', 'refunded')

)

select
    branch_code,
    order_date,
    count(*)                                                as orders,
    sum(total_amount)                                       as expected_takings,
    sum(total_paid)                                         as actual_takings,
    sum(total_paid) - sum(total_amount)                     as variance,
    count(*) filter (where abs(total_paid - total_amount) > 0.01)
                                                            as orders_with_variance,
    abs(sum(total_paid) - sum(total_amount)) > 0.01         as is_flagged
from orders
group by 1, 2
