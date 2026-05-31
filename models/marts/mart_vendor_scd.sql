with base as (
    select * from {{ ref('int_trips_enriched') }}
),

-- aggregate vendor stats per month to simulate changing vendor metrics
vendor_monthly as (
    select
        vendor_id,
        pickup_month                                        as effective_from,
        lead(pickup_month) over (
            partition by vendor_id
            order by pickup_month
        )                                                   as effective_to,

        count(*)                                            as monthly_trips,
        round(sum(total_amount), 2)                         as monthly_revenue,
        round(avg(total_amount), 2)                         as avg_fare,
        round(avg(trip_distance), 2)                        as avg_distance,
        round(avg(trip_duration_minutes), 2)                as avg_duration_minutes,

        -- rank vendors by revenue each month
        rank() over (
            order by sum(total_amount) desc
        )                                                   as revenue_rank

    from base
    group by
        vendor_id,
        pickup_month
)

select
    vendor_id,
    effective_from,
    coalesce(effective_to, '9999-12-31')                    as effective_to,
    case
        when effective_to is null then true
        else false
    end                                                      as is_current,
    monthly_trips,
    monthly_revenue,
    avg_fare,
    avg_distance,
    avg_duration_minutes,
    revenue_rank
from vendor_monthly
order by vendor_id, effective_from