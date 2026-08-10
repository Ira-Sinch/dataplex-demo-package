{{ config(
    materialized='table',
    alias='customer'
) }}

select
    'C101' as customer_id,
    'Microsoft Inc' as customer_name,
    '123456789' as phone_number