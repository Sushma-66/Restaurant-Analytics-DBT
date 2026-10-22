with members as (

    select * from {{ ref('stg_crm__members') }}

),

order_stats as (

    select
        member_id,
        min(order_date)                     as first_order_date,
        max(order_date)                     as last_order_date,
        count(*)                            as lifetime_orders,
        sum(net_sales_amount)               as lifetime_net_sales
    from {{ ref('int_orders__enriched') }}
    where is_revenue_order and member_id is not null
    group by 1

)

select
    members.member_id,
    members.home_branch_code,
    members.signed_up_at,
    members.signed_up_on,
    members.has_marketing_consent,
    members.is_sushi_club,
    order_stats.first_order_date,
    order_stats.last_order_date,
    cast(coalesce(order_stats.lifetime_orders, 0) as integer)          as lifetime_orders,
    cast(coalesce(order_stats.lifetime_net_sales, 0) as decimal(14, 2)) as lifetime_net_sales,
    order_stats.member_id is null                           as is_dormant,
    -- PII is deliberately NOT exposed here; see dim_members_pii (restricted)
    {{ dbt_utils.generate_surrogate_key(['members.email']) }} as email_hash
from members
left join order_stats on members.member_id = order_stats.member_id
