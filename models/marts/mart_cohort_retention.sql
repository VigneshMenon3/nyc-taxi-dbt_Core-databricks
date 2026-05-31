{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key='cohort_period_key',
        on_schema_change='sync_all_columns'
    )
}}

with base as (
    select * from {{ ref('int_trips_enriched') }}

    {% if is_incremental() %}
        where pickup_datetime > (
            select max(cohort_month) from {{ this }}
        )
    {% endif %}
),

first_trips as (
    select
        pickup_location_id                              as rider_id,
        min(date_trunc('month', pickup_datetime))       as cohort_month
    from base
    group by pickup_location_id
),

trips_with_cohort as (
    select
        b.pickup_location_id                            as rider_id,
        f.cohort_month,
        date_trunc('month', b.pickup_datetime)          as trip_month
    from base b
    inner join first_trips f
        on b.pickup_location_id = f.rider_id
),

cohort_periods as (
    select
        rider_id,
        cohort_month,
        trip_month,
        datediff(month, cohort_month, trip_month)       as period_number
    from trips_with_cohort
),

retention as (
    select
        cohort_month,
        period_number,
        count(distinct rider_id)                        as retained_riders
    from cohort_periods
    group by cohort_month, period_number
),

cohort_sizes as (
    select
        cohort_month,
        retained_riders                                 as cohort_size
    from retention
    where period_number = 0
)

select
    r.cohort_month,
    r.period_number,
    r.retained_riders,
    c.cohort_size,
    round(r.retained_riders * 100.0 / c.cohort_size, 2) as retention_pct,

    -- unique key for merge
    concat(
        cast(r.cohort_month as string),
        '_',
        cast(r.period_number as string)
    )                                                    as cohort_period_key

from retention r
inner join cohort_sizes c
    on r.cohort_month = c.cohort_month
order by r.cohort_month, r.period_number