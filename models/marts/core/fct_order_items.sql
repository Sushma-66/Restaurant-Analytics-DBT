{{
    config(
        materialized = 'incremental',
        unique_key = 'order_item_id',
        incremental_strategy = 'delete+insert',
        on_schema_change = 'append_new_columns'
    )
}}

with items as (

    select * from {{ ref('int_order_items__costed') }}

),

orders as (

    select
        order_id,
        branch_code,
        order_date,
        order_status,
        promo_code,
        member_id,
        _loaded_at
    from {{ ref('stg_pos__orders') }}

    {% if is_incremental() %}
    where _loaded_at >= (
        select max(existing._loaded_at) - interval '{{ var("incremental_lookback_days") }} days'
        from {{ this }} as existing
    )
    {% endif %}

)

select
    items.order_item_id,
    items.order_id,
    items.line_number,
    orders.branch_code,
    orders.order_date,
    orders.order_status,
    orders.promo_code,
    orders.member_id,
    items.sku,
    items.item_name,
    items.category,
    items.quantity,
    items.unit_price,
    items.line_gross_amount,
    items.line_discount,
    items.line_net_amount,
    items.unit_cost,
    items.line_cost_amount,
    items.line_gross_profit,
    items.is_cost_estimated,
    orders._loaded_at
from items
inner join orders on items.order_id = orders.order_id
