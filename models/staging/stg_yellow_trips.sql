with source as (
    select * from {{ source('nyc_taxi_raw', 'raw_yellow_trips') }}
),

cleaned as (
    select
        VendorID                                            as vendor_id,
        tpep_pickup_datetime                                as pickup_datetime,
        tpep_dropoff_datetime                               as dropoff_datetime,
        passenger_count,
        trip_distance,
        PULocationID                                        as pickup_location_id,
        DOLocationID                                        as dropoff_location_id,
        payment_type,
        fare_amount,
        tip_amount,
        tolls_amount,
        total_amount,

        -- derived columns
        (unix_timestamp(tpep_dropoff_datetime)
          - unix_timestamp(tpep_pickup_datetime)) / 60      as trip_duration_minutes,

        date_trunc('month', tpep_pickup_datetime)           as pickup_month

    from source

    where
        tpep_pickup_datetime >= '2025-12-01'
        and tpep_pickup_datetime <  '2026-03-01'
        and trip_distance > 0
        and total_amount > 0
        and passenger_count > 0
        and passenger_count <= 6
)

select * from cleaned