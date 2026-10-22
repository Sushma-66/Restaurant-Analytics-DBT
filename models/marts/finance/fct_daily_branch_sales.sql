{#
    Grain: one row per branch per trading day.

    This is the warehouse version of the end-of-day (EOD) report a restaurant
    manager produces every night: sales, covers, spend per head, discounts,
    tender mix and week-on-week movement.
#}

with orders as (

    select * from {{ ref('fct_orders') }}

),

daily as (

    select
        branch_code,
        order_date,

        count(*) filter (where is_revenue_order)                            as orders,
        count(*) filter (where order_status = 'voided')                     as voided_orders,
        count(*) filter (where order_status = 'refunded')                   as refunded_orders,
        sum(covers) filter (where is_revenue_order and channel = 'dine_in') as dine_in_covers,

        sum(gross_amount)       filter (where is_revenue_order)             as gross_sales,
        sum(discount_amount)    filter (where is_revenue_order)             as discounts,
        sum(net_sales_amount)   filter (where is_revenue_order)             as net_sales,
        sum(net_sales_ex_vat)   filter (where is_revenue_order)             as net_sales_ex_vat,
        sum(vat_amount)         filter (where is_revenue_order)             as vat,
        sum(service_charge)     filter (where is_revenue_order)             as service_charge,
        sum(cost_amount)        filter (where is_revenue_order)             as cost_of_sales,
        sum(total_tips)                                                     as tips,

        sum(net_sales_amount) filter (where is_revenue_order and channel = 'dine_in')           as dine_in_sales,
        sum(net_sales_amount) filter (where is_revenue_order and channel = 'takeaway')          as takeaway_sales,
        sum(net_sales_amount) filter (where is_revenue_order and channel like 'delivery_%')     as delivery_sales,

        sum(paid_electronic)    filter (where is_revenue_order)             as tender_card,
        sum(paid_cash)          filter (where is_revenue_order)             as tender_cash,
        sum(paid_stored_value)  filter (where is_revenue_order)             as tender_gift_card,
        sum(paid_third_party)   filter (where is_revenue_order)             as tender_third_party

    from orders
    group by 1, 2

),

final as (

    select
        {{ dbt_utils.generate_surrogate_key(['branch_code', 'order_date']) }} as branch_day_id,
        daily.*,
        round(net_sales / nullif(orders, 0), 2)                             as avg_order_value,
        round(dine_in_sales / nullif(dine_in_covers, 0), 2)                 as spend_per_head,
        round(discounts / nullif(gross_sales, 0), 4)                        as discount_rate,
        round(1 - cost_of_sales / nullif(net_sales_ex_vat, 0), 4)           as gross_margin_pct,

        -- Same weekday last week - the comparison managers actually use
        lag(net_sales, 7) over (partition by branch_code order by order_date) as net_sales_same_day_last_week,
        round(
            net_sales / nullif(lag(net_sales, 7) over (partition by branch_code order by order_date), 0) - 1,
            4
        )                                                                   as net_sales_wow_pct

    from daily

)

select
    branch_day_id,
    branch_code,
    order_date,
    cast(orders as integer)                         as orders,
    cast(voided_orders as integer)                  as voided_orders,
    cast(refunded_orders as integer)                as refunded_orders,
    cast(dine_in_covers as integer)                 as dine_in_covers,
    {%- for col in ['gross_sales', 'discounts', 'net_sales', 'net_sales_ex_vat', 'vat', 'service_charge',
                    'cost_of_sales', 'tips', 'dine_in_sales', 'takeaway_sales', 'delivery_sales',
                    'tender_card', 'tender_cash', 'tender_gift_card', 'tender_third_party',
                    'avg_order_value', 'spend_per_head', 'net_sales_same_day_last_week'] %}
    cast({{ col }} as decimal(14, 2))               as {{ col }},
    {%- endfor %}
    cast(discount_rate as decimal(8, 4))            as discount_rate,
    cast(gross_margin_pct as decimal(8, 4))         as gross_margin_pct,
    cast(net_sales_wow_pct as decimal(8, 4))        as net_sales_wow_pct
from final
