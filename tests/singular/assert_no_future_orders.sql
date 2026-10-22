-- Orders can't be in the future. Guards against timezone / clock bugs in the POS export.
select order_id, ordered_at
from {{ ref('fct_orders') }}
where ordered_at > current_timestamp + interval 1 day
