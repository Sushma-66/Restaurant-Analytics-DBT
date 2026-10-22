with branches as (

    select * from {{ ref('branches') }}

),

trading as (

    select
        branch_code,
        min(order_date)     as first_trading_date,
        max(order_date)     as last_trading_date
    from {{ ref('stg_pos__orders') }}
    group by 1

)

select
    branches.branch_code,
    branches.branch_name,
    branches.city,
    branches.region,
    branches.opened_on,
    branches.seat_capacity,
    branches.is_franchise,
    trading.first_trading_date,
    trading.last_trading_date
from branches
left join trading on branches.branch_code = trading.branch_code
