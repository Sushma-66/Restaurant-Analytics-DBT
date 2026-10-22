-- An order dated before its branch opened means a mis-keyed branch code or a bad clock on the till.
select
    o.order_id,
    o.branch_code,
    o.order_date,
    b.opened_on
from {{ ref('fct_orders') }} as o
inner join {{ ref('dim_branches') }} as b
    on o.branch_code = b.branch_code
where o.order_date < b.opened_on
