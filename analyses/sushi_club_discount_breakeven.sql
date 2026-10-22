-- Ad-hoc: is the 50% Sushi Club discount paying for itself?
-- Compares club members' spend in the 90 days before vs after their first SUSHICLUB50 order.
with first_promo as (
    select member_id, min(order_date) as first_promo_date
    from {{ ref('fct_orders') }}
    where promo_code = 'SUSHICLUB50' and is_revenue_order
    group by 1
),

windows as (
    select
        f.member_id,
        sum(case when o.order_date <  f.first_promo_date
                  and o.order_date >= f.first_promo_date - interval 90 day
                 then o.gross_profit_ex_vat else 0 end)     as gp_90d_before,
        sum(case when o.order_date >= f.first_promo_date
                  and o.order_date <  f.first_promo_date + interval 90 day
                 then o.gross_profit_ex_vat else 0 end)     as gp_90d_after
    from first_promo as f
    inner join {{ ref('fct_orders') }} as o
        on f.member_id = o.member_id and o.is_revenue_order
    group by 1
)

select
    count(*)                                                as members,
    round(avg(gp_90d_before), 2)                            as avg_gross_profit_90d_before,
    round(avg(gp_90d_after), 2)                             as avg_gross_profit_90d_after,
    round(avg(gp_90d_after) - avg(gp_90d_before), 2)        as avg_uplift_per_member
from windows
