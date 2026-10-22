{#
    Order lines costed at the menu cost that applied when the order was placed.

    Point-in-time join to the SCD2 snapshot. Orders that pre-date the first
    snapshot (history before the pipeline went live) fall back to the current
    cost-to-price ratio, and are flagged so analysts know the cost is estimated.
#}

with items as (

    select * from {{ ref('stg_pos__order_items') }}

),

orders as (

    select
        order_id,
        ordered_at
    from {{ ref('stg_pos__orders') }}

),

menu_history as (

    select * from {{ ref('snap_menu_items') }}

),

menu_current as (

    select * from {{ ref('stg_pos__menu_items') }}

),

joined as (

    select
        items.order_item_id,
        items.order_id,
        items.line_number,
        items.sku,
        menu_current.item_name,
        menu_current.category,
        items.quantity,
        items.unit_price,
        items.line_discount,
        orders.ordered_at,

        items.unit_price * items.quantity                               as line_gross_amount,
        items.unit_price * items.quantity - items.line_discount         as line_net_amount,

        cast(coalesce(
            menu_history.unit_cost,
            round(items.unit_price * menu_current.unit_cost / nullif(menu_current.price, 0), 2)
        ) as decimal(12, 2))                                            as unit_cost,

        menu_history.sku is null                                        as is_cost_estimated

    from items
    inner join orders
        on items.order_id = orders.order_id
    left join menu_current
        on items.sku = menu_current.sku
    left join menu_history
        on items.sku = menu_history.sku
        and orders.ordered_at >= menu_history.dbt_valid_from
        and orders.ordered_at <  menu_history.dbt_valid_to

)

select
    *,
    unit_cost * quantity                                as line_cost_amount,
    line_net_amount - unit_cost * quantity              as line_gross_profit
from joined
