with source as (

    select * from {{ source('pos', 'order_items') }}

),

renamed as (

    select
        {{ dbt_utils.generate_surrogate_key(['order_id', 'line_number']) }} as order_item_id,
        order_id,
        cast(line_number as integer)                as line_number,
        upper(trim(sku))                            as sku,
        cast(quantity as integer)                   as quantity,
        {{ parse_money('unit_price') }}             as unit_price,
        {{ parse_money('line_discount') }}          as line_discount

    from source

)

select * from renamed
