with orders as (

    select * from {{ ref('stg_pos__orders') }}

),

items as (

    select
        order_id,
        count(*)                                        as line_count,
        sum(quantity)                                   as item_quantity,
        sum(line_cost_amount)                           as cost_amount,
        bool_or(is_cost_estimated)                      as is_cost_estimated
    from {{ ref('int_order_items__costed') }}
    group by 1

),

payments as (

    select * from {{ ref('int_payments__pivoted_to_order') }}

)

select
    orders.*,

    -- Net sales = what the customer paid for food & drink (excl. service charge)
    orders.gross_amount - orders.discount_amount                        as net_sales_amount,
    {{ net_of_vat('orders.gross_amount - orders.discount_amount') }}    as net_sales_ex_vat,
    {{ vat_amount('orders.gross_amount - orders.discount_amount') }}    as vat_amount,

    coalesce(items.line_count, 0)                                       as line_count,
    coalesce(items.item_quantity, 0)                                    as item_quantity,
    coalesce(items.cost_amount, 0)                                      as cost_amount,
    coalesce(items.is_cost_estimated, false)                            as is_cost_estimated,

    coalesce(payments.payment_count, 0)                                 as payment_count,
    coalesce(payments.total_paid, 0)                                    as total_paid,
    coalesce(payments.total_tips, 0)                                    as total_tips,
    coalesce(payments.paid_electronic, 0)                               as paid_electronic,
    coalesce(payments.paid_cash, 0)                                     as paid_cash,
    coalesce(payments.paid_stored_value, 0)                             as paid_stored_value,
    coalesce(payments.paid_third_party, 0)                              as paid_third_party,

    orders.order_status = 'completed'                                   as is_revenue_order,
    orders.member_id is not null                                        as is_member_order

from orders
left join items    on orders.order_id = items.order_id
left join payments on orders.order_id = payments.order_id
