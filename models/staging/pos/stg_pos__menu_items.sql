with source as (

    select * from {{ source('pos', 'menu_items') }}

),

renamed as (

    select
        upper(trim(sku))                            as sku,
        trim(item_name)                             as item_name,
        trim(category)                              as category,
        {{ parse_money('price') }}                  as price,
        cast(unit_cost as decimal(12, 2))           as unit_cost,
        cast(is_active as boolean)                  as is_active,
        cast(updated_at as timestamp)               as updated_at

    from source

)

select * from renamed
