with source as (

    select * from {{ source('pos', 'orders') }}

),

-- Re-exported files land the same order twice: keep the most recent load
deduplicated as (

    select *
    from source
    qualify row_number() over (
        partition by order_id
        order by cast(_loaded_at as timestamp) desc
    ) = 1

),

renamed as (

    select
        -- ids
        order_id,
        upper(trim(branch_code))                    as branch_code,
        nullif(trim(member_id), '')                 as member_id,
        nullif(upper(trim(promo_code)), '')         as promo_code,

        -- attributes
        {{ clean_code('channel') }}                 as channel,
        {{ clean_code('order_status') }}            as order_status,
        cast(covers as integer)                     as covers,

        -- amounts (VAT-inclusive, GBP)
        {{ parse_money('gross_amount') }}           as gross_amount,
        {{ parse_money('discount_amount') }}        as discount_amount,
        {{ parse_money('service_charge') }}         as service_charge,
        {{ parse_money('total_amount') }}           as total_amount,

        -- timestamps
        cast(ordered_at as timestamp)               as ordered_at,
        cast(ordered_at as date)                    as order_date,
        cast(_loaded_at as timestamp)               as _loaded_at

    from deduplicated

)

select * from renamed
