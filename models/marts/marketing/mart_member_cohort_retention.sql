{#
    Grain: one row per acquisition cohort (month of first order) per month offset.
    Classic retention triangle - % of a cohort that ordered again N months later.
#}

with member_months as (

    select distinct
        member_id,
        cast(date_trunc('month', order_date) as date)       as activity_month
    from {{ ref('fct_orders') }}
    where is_revenue_order and member_id is not null

),

cohorts as (

    select
        member_id,
        min(activity_month) as cohort_month
    from member_months
    group by 1

),

activity as (

    select
        cohorts.cohort_month,
        date_diff('month', cohorts.cohort_month, member_months.activity_month) as months_since_first_order,
        count(distinct member_months.member_id)             as active_members
    from member_months
    inner join cohorts on member_months.member_id = cohorts.member_id
    group by 1, 2

),

cohort_size as (

    select
        cohort_month,
        count(*) as cohort_members
    from cohorts
    group by 1

)

select
    activity.cohort_month,
    activity.months_since_first_order,
    cohort_size.cohort_members,
    activity.active_members,
    round(activity.active_members / cohort_size.cohort_members, 4) as retention_rate
from activity
inner join cohort_size on activity.cohort_month = cohort_size.cohort_month
