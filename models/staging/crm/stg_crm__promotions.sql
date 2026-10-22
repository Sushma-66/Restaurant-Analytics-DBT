with source as (

    select * from {{ source('crm', 'promotions') }}

),

renamed as (

    select
        upper(trim(promo_code))                     as promo_code,
        trim(promo_name)                            as promo_name,
        cast(discount_pct as decimal(5, 4))         as discount_pct,
        nullif(trim(applies_to_category), '')       as applies_to_category,
        cast(valid_from as date)                    as valid_from,
        cast(valid_to as date)                      as valid_to,
        cast(is_member_only as boolean)             as is_member_only

    from source

)

select * from renamed
