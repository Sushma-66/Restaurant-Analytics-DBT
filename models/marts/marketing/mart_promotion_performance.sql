{#
    Grain: one row per promotion per month.

    Answers the commercial question "does the discount pay for itself?":
    discount cost vs gross profit retained, and whether promo customers come
    back within 30 days without a promotion.
#}

with orders as (

    select * from {{ ref('fct_orders') }}
    where is_revenue_order

),

promos as (

    select * from {{ ref('stg_crm__promotions') }}

),

-- For each promo order by a member, did that member place a full-price order in the next 30 days?
promo_orders as (

    select
        o.order_id,
        o.promo_code,
        o.member_id,
        o.order_date,
        exists(
            select 1
            from orders as nxt
            where nxt.member_id = o.member_id
              and nxt.promo_code is null
              and nxt.order_date > o.order_date
              and nxt.order_date <= o.order_date + interval 30 day
        )                                                   as returned_full_price_30d
    from orders as o
    where o.promo_code is not null

),

monthly as (

    select
        orders.promo_code,
        cast(date_trunc('month', orders.order_date) as date) as month_start,
        count(*)                                            as orders,
        count(distinct orders.member_id)                    as unique_members,
        sum(orders.gross_amount)                            as gross_sales,
        sum(orders.discount_amount)                         as discount_cost,
        sum(orders.net_sales_amount)                        as net_sales,
        sum(orders.gross_profit_ex_vat)                     as gross_profit_ex_vat,
        avg(case when promo_orders.member_id is not null
                 then cast(promo_orders.returned_full_price_30d as integer) end) as member_full_price_return_rate_30d
    from orders
    inner join promo_orders on orders.order_id = promo_orders.order_id
    group by 1, 2

)

select
    monthly.promo_code,
    promos.promo_name,
    promos.is_member_only,
    monthly.month_start,
    monthly.orders,
    monthly.unique_members,
    monthly.gross_sales,
    monthly.discount_cost,
    monthly.net_sales,
    monthly.gross_profit_ex_vat,
    round(monthly.discount_cost / nullif(monthly.gross_sales, 0), 4)        as effective_discount_rate,
    round(monthly.gross_profit_ex_vat / nullif(monthly.net_sales, 0), 4)    as gross_margin_on_net_sales,
    round(monthly.member_full_price_return_rate_30d, 4)                     as member_full_price_return_rate_30d
from monthly
left join promos on monthly.promo_code = promos.promo_code
