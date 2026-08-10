{{ config(
    materialized='table',
    alias='customer_orders'
) }}

select 
    1 as order_id, 
    'C101' as customer_id, 
    55.50 as order_amount, 
    date '2026-07-01' as order_date

union all

select 
    2 as order_id, 
    'C101' as customer_id, 
    120.00 as order_amount, 
    date '2026-07-02' as order_date
