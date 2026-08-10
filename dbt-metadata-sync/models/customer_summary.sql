{{ config(
    materialized='view',
    alias='customer_summary'
) }}

with customer as (
    select * from {{ ref('customer_demo') }}
),

orders as (
    select * from {{ ref('orders') }}
),

aggregated_orders as (
    select
        customer_id,
        count(order_id) as total_orders,
        sum(order_amount) as total_amount_spent
    from orders
    group by 1
)

select
    c.customer_id,
    c.customer_name,
    c.phone_number,
    coalesce(o.total_orders, 0) as total_orders,
    coalesce(o.total_amount_spent, 0.00) as total_amount_spent
from customer c
left join aggregated_orders o 
    on c.customer_id = o.customer_id
