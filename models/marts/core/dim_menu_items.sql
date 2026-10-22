select
    sku,
    item_name,
    category,
    price                                                   as current_price,
    unit_cost                                               as current_unit_cost,
    round(1 - unit_cost / nullif(price, 0), 4)              as current_gross_margin_pct,
    is_active,
    updated_at                                              as price_last_changed_at
from {{ ref('stg_pos__menu_items') }}
