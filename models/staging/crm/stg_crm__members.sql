with source as (

    select * from {{ source('crm', 'members') }}

),

renamed as (

    select
        member_id,
        trim(first_name)                            as first_name,
        trim(last_name)                             as last_name,
        lower(trim(email))                          as email,
        upper(trim(home_branch))                    as home_branch_code,
        cast(signed_up_at as timestamp)             as signed_up_at,
        cast(signed_up_at as date)                  as signed_up_on,

        -- The CRM stores consent as Y / y / Yes / N / blank. Blank = no consent (GDPR default).
        coalesce(lower(trim(marketing_opt_in)) in ('y', 'yes'), false)
                                                    as has_marketing_consent,
        cast(is_sushi_club as boolean)              as is_sushi_club

    from source

)

select * from renamed
