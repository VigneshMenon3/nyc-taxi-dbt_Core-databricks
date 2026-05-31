with base as (
    select * from {{ ref('stg_yellow_trips') }}
),

deduped as (
    select *,
        row_number() over (
            partition by pickup_datetime, pickup_location_id, dropoff_location_id, total_amount
            order by pickup_datetime
        ) as row_num
    from base
),

enriched as (
    select
        vendor_id,
        pickup_datetime,
        dropoff_datetime,
        passenger_count,
        trip_distance,
        pickup_location_id,
        dropoff_location_id,
        payment_type,
        fare_amount,
        tip_amount,
        tolls_amount,
        total_amount,
        trip_duration_minutes,
        pickup_month,

        -- trip categorization
        case
            when trip_distance < 1    then 'short'
            when trip_distance < 5    then 'medium'
            else                           'long'
        end as trip_category,

        -- tip behavior
        case
            when tip_amount = 0       then 'no_tip'
            when tip_amount < 3       then 'low_tip'
            when tip_amount < 7       then 'medium_tip'
            else                           'high_tip'
        end as tip_category,

        -- payment label
        case payment_type
            when 1 then 'credit_card'
            when 2 then 'cash'
            when 3 then 'no_charge'
            when 4 then 'dispute'
            else        'unknown'
        end as payment_label,

        -- time of day
        case
            when hour(pickup_datetime) between 6  and 11 then 'morning'
            when hour(pickup_datetime) between 12 and 16 then 'afternoon'
            when hour(pickup_datetime) between 17 and 20 then 'evening'
            else                                              'night'
        end as time_of_day,

        -- day of week
        date_format(pickup_datetime, 'EEEE')    as day_of_week,

        -- window functions
        rank() over (
            partition by vendor_id, date_trunc('day', pickup_datetime)
            order by total_amount desc
        ) as rank_by_fare_per_vendor_day,

        sum(total_amount) over (
            partition by vendor_id
            order by pickup_datetime
            rows between unbounded preceding and current row
        ) as running_total_revenue,

        lag(pickup_datetime) over (
            partition by vendor_id
            order by pickup_datetime
        ) as prev_trip_pickup,

        datediff(
            minute,
            lag(pickup_datetime) over (
                partition by vendor_id
                order by pickup_datetime
            ),
            pickup_datetime
        ) as minutes_since_last_trip

    from deduped
    where row_num = 1
)

select * from enriched