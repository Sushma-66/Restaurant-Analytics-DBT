with source as (

    select * from {{ source('pos', 'payments') }}

),

mapping as (

    select * from {{ ref('payment_method_mapping') }}

),

renamed as (

    select
        source.payment_id,
        source.order_id,
        {{ clean_code('source.payment_method') }}   as raw_payment_method,
        mapping.payment_method,
        mapping.payment_group,
        {{ parse_money('source.amount') }}          as amount,
        {{ parse_money('source.tip_amount') }}      as tip_amount,
        cast(source.paid_at as timestamp)           as paid_at

    from source
    left join mapping
        on {{ clean_code('source.payment_method') }} = mapping.raw_payment_method

)

select * from renamed
