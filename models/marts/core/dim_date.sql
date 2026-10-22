with spine as (

    {{ dbt_utils.date_spine(
        datepart = "day",
        start_date = "cast('2021-01-01' as date)",
        end_date = "cast('2027-12-31' as date)"
    ) }}

)

select
    cast(date_day as date)                                  as date_day,
    extract(year from date_day)                             as year,
    extract(quarter from date_day)                          as quarter,
    extract(month from date_day)                            as month,
    strftime(date_day, '%B')                                as month_name,
    cast(date_trunc('month', date_day) as date)             as month_start,
    cast(date_trunc('week', date_day) as date)              as week_start,   -- ISO week, Monday
    extract(isodow from date_day)                           as iso_day_of_week,
    strftime(date_day, '%A')                                as day_name,
    extract(isodow from date_day) in (5, 6, 7)              as is_weekend_trading,  -- Fri-Sun
    -- UK fiscal year runs 6 April - 5 April
    case
        when date_day >= make_date(cast(extract(year from date_day) as int), 4, 6)
            then extract(year from date_day)
        else extract(year from date_day) - 1
    end                                                     as uk_fiscal_year
from spine
