{#
    RFM segmentation of loyalty members, scored as of var('rfm_as_of_date').

    Each of Recency, Frequency and Monetary is scored 1-5 by quintile
    (5 = best). Segments follow the common RFM naming convention.
#}

{%- set as_of = "cast('" ~ var('rfm_as_of_date') ~ "' as date)" -%}

with member_orders as (

    select
        member_id,
        max(order_date)                                     as last_order_date,
        count(*)                                            as frequency,
        sum(net_sales_amount)                               as monetary
    from {{ ref('fct_orders') }}
    where is_revenue_order
      and member_id is not null
      and order_date <= {{ as_of }}
    group by 1

),

scored as (

    select
        member_id,
        last_order_date,
        date_diff('day', last_order_date, {{ as_of }})      as recency_days,
        frequency,
        monetary,
        ntile(5) over (order by date_diff('day', last_order_date, {{ as_of }}) desc) as r_score,
        ntile(5) over (order by frequency asc, monetary asc)                         as f_score,
        ntile(5) over (order by monetary asc)                                        as m_score
    from member_orders

)

select
    *,
    r_score * 100 + f_score * 10 + m_score                  as rfm_cell,
    case
        when r_score >= 4 and f_score >= 4                  then 'Champions'
        when r_score >= 3 and f_score >= 3                  then 'Loyal'
        when r_score >= 4 and f_score <= 2                  then 'New / Promising'
        when r_score <= 2 and f_score >= 4                  then 'At Risk'
        when r_score <= 2 and f_score <= 2                  then 'Lost'
        else 'Needs Attention'
    end                                                     as rfm_segment
from scored
