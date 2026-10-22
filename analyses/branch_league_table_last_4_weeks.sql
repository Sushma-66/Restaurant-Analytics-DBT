-- Ad-hoc: branch league table for the last 4 complete weeks.
-- Compile with `dbt compile -s branch_league_table_last_4_weeks` and run in your SQL client.
with last_date as (
    select max(order_date) as max_date from {{ ref('fct_daily_branch_sales') }}
)

select
    s.branch_code,
    b.branch_name,
    sum(s.net_sales)                                        as net_sales,
    sum(s.orders)                                           as orders,
    round(sum(s.net_sales) / nullif(sum(s.orders), 0), 2)   as avg_order_value,
    round(avg(s.spend_per_head), 2)                         as avg_spend_per_head,
    round(avg(s.gross_margin_pct), 4)                       as avg_gross_margin_pct,
    rank() over (order by sum(s.net_sales) desc)            as sales_rank
from {{ ref('fct_daily_branch_sales') }} as s
inner join {{ ref('dim_branches') }} as b on s.branch_code = b.branch_code
cross join last_date
where s.order_date > last_date.max_date - interval 28 day
group by 1, 2
order by sales_rank
