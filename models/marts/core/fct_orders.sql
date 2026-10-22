{{
    config(
        materialized = 'incremental',
        unique_key = 'order_id',
        incremental_strategy = 'delete+insert',
        on_schema_change = 'append_new_columns'
    )
}}

{#
    Grain: one row per order (deduplicated).

    Incremental: on each run only orders loaded in the last
    `incremental_lookback_days` (relative to the newest row already in the
    table) are reprocessed. The look-back window catches late re-exports and
    status changes such as refunds made the next day.
    Full rebuild:  dbt build -s fct_orders --full-refresh
#}

with orders as (

    select * from {{ ref('int_orders__enriched') }}

    {% if is_incremental() %}
    where _loaded_at >= (
        select max(existing._loaded_at) - interval '{{ var("incremental_lookback_days") }} days'
        from {{ this }} as existing
    )
    {% endif %}

)

select
    cast(order_id as varchar)                               as order_id,
    cast(branch_code as varchar)                            as branch_code,
    cast(member_id as varchar)                              as member_id,
    cast(promo_code as varchar)                             as promo_code,
    order_date,
    ordered_at,
    channel,
    order_status,
    cast(covers as integer)                                 as covers,
    cast(line_count as integer)                             as line_count,
    cast(item_quantity as integer)                          as item_quantity,
    cast(gross_amount as decimal(12, 2))                    as gross_amount,
    cast(discount_amount as decimal(12, 2))                 as discount_amount,
    cast(net_sales_amount as decimal(12, 2))                as net_sales_amount,
    cast(net_sales_ex_vat as decimal(12, 2))                as net_sales_ex_vat,
    cast(vat_amount as decimal(12, 2))                      as vat_amount,
    cast(service_charge as decimal(12, 2))                  as service_charge,
    cast(total_amount as decimal(12, 2))                    as total_amount,
    cast(cost_amount as decimal(12, 2))                     as cost_amount,
    cast(net_sales_ex_vat - cost_amount as decimal(12, 2))  as gross_profit_ex_vat,
    cast(payment_count as integer)                          as payment_count,
    cast(total_paid as decimal(12, 2))                      as total_paid,
    cast(total_tips as decimal(12, 2))                      as total_tips,
    cast(paid_electronic as decimal(12, 2))                 as paid_electronic,
    cast(paid_cash as decimal(12, 2))                       as paid_cash,
    cast(paid_stored_value as decimal(12, 2))               as paid_stored_value,
    cast(paid_third_party as decimal(12, 2))                as paid_third_party,
    is_revenue_order,
    is_member_order,
    is_cost_estimated,
    _loaded_at
from orders
