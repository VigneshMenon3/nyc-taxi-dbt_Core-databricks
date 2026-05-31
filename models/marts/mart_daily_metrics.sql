with base as (
    select * from {{ ref('int_trips_enriched') }}
),

daily as (
    select
        date_trunc('day', pickup_datetime)                          as trip_date,
        vendor_id,
        day_of_week,

        -- volume metrics
        count(*)                                                    as total_trips,
        sum(passenger_count)                                        as total_passengers,

        -- revenue metrics
        round(sum(total_amount), 2)                                 as total_revenue,
        round(avg(total_amount), 2)                                 as avg_fare,
        round(sum(tip_amount), 2)                                   as total_tips,
        round(avg(tip_amount), 2)                                   as avg_tip,

        -- trip distance metrics
        round(avg(trip_distance), 2)                                as avg_distance,
        round(sum(trip_distance), 2)                                as total_distance,

        -- duration metrics
        round(avg(trip_duration_minutes), 2)                        as avg_duration_minutes,

        -- conditional aggregations
        count(case when trip_category = 'long'   then 1 end)        as long_trips,
        count(case when trip_category = 'medium' then 1 end)        as medium_trips,
        count(case when trip_category = 'short'  then 1 end)        as short_trips,

        count(case when payment_label = 'credit_card' then 1 end)   as credit_card_trips,
        count(case when payment_label = 'cash'        then 1 end)   as cash_trips,

        count(case when tip_category = 'no_tip'  then 1 end)        as no_tip_trips,
        count(case when tip_category = 'high_tip' then 1 end)       as high_tip_trips,

        count(case when time_of_day = 'morning'   then 1 end)       as morning_trips,
        count(case when time_of_day = 'afternoon' then 1 end)       as afternoon_trips,
        count(case when time_of_day = 'evening'   then 1 end)       as evening_trips,
        count(case when time_of_day = 'night'     then 1 end)       as night_trips,

        -- running revenue
        round(sum(sum(total_amount)) over (
            partition by vendor_id
            order by date_trunc('day', pickup_datetime)
            rows between unbounded preceding and current row
        ), 2)                                                        as cumulative_revenue

    from base
    group by
        date_trunc('day', pickup_datetime),
        vendor_id,
        day_of_week
)

select * from daily
order by trip_date, vendor_id