-- The daily summary must tie back exactly to the order-level fact (no double counting in the roll-up).
with from_daily as (
    select sum(net_sales) as net_sales from {{ ref('fct_daily_branch_sales') }}
),
from_orders as (
    select sum(net_sales_amount) as net_sales from {{ ref('fct_orders') }} where is_revenue_order
)
select *
from from_daily, from_orders
where abs(from_daily.net_sales - from_orders.net_sales) > 0.01
