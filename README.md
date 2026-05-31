# NYC TLC Taxi Analytics — dbt Core + Databricks

An end-to-end data engineering project that transforms 7M+ raw NYC yellow 
taxi trips into a structured, tested, and documented analytics layer using 
the Medallion architecture on Databricks with dbt Core.

---

## Tech Stack

| Tool | Purpose |
|------|---------|
| Databricks | Cloud lakehouse compute and storage |
| Delta Lake | ACID-compliant table format on DBFS |
| PySpark | Raw data ingestion and Delta table creation |
| dbt Core 1.11 | SQL transformation, testing, and documentation |
| Unity Catalog | Three-level namespace data governance |
| GitHub | Version control |

---

## Architecture — Medallion Pattern

![Lineage DAG](docs/lineage_dag.png)

---

## Project Structure

---

## dbt Transformations — Layer by Layer

### Staging — `stg_yellow_trips`
Materialized as a **view**. Performs light, safe transformations directly 
on the raw Delta table:
- Renames all columns to `snake_case`
- Casts columns to correct data types
- Filters out bad data — zero distance trips, negative fares, invalid 
  passenger counts
- Adds derived column `trip_duration_minutes` calculated from pickup 
  and dropoff timestamps
- Adds `pickup_month` using `DATE_TRUNC` for downstream partitioning

### Intermediate — `int_trips_enriched`
Materialized as a **view**. Enriches the staging data with analytical 
columns without aggregating:

**Deduplication**
```sql
row_number() over (
    partition by pickup_datetime, pickup_location_id, 
                 dropoff_location_id, total_amount
    order by pickup_datetime
) as row_num
```

**Trip and tip categorization using CASE WHEN**
```sql
case
    when trip_distance < 1 then 'short'
    when trip_distance < 5 then 'medium'
    else                        'long'
end as trip_category
```

**Ranking trips by fare per vendor per day**
```sql
rank() over (
    partition by vendor_id, date_trunc('day', pickup_datetime)
    order by total_amount desc
) as rank_by_fare_per_vendor_day
```

**Running total revenue per vendor**
```sql
sum(total_amount) over (
    partition by vendor_id
    order by pickup_datetime
    rows between unbounded preceding and current row
) as running_total_revenue
```

**Sessionization using LAG**
```sql
datediff(
    minute,
    lag(pickup_datetime) over (
        partition by vendor_id
        order by pickup_datetime
    ),
    pickup_datetime
) as minutes_since_last_trip
```

### Marts — Gold Layer
Materialized as **incremental tables** using `merge` strategy with a 
`unique_key` — only new data is processed on each run, making the 
pipeline efficient at scale.

**`mart_daily_metrics`**
Daily aggregations per vendor including total trips, total revenue, 
average fare, average duration, and conditional aggregations for 
trip category splits, payment method breakdown, and time of day 
distribution.

```sql
count(case when trip_category = 'long'    then 1 end) as long_trips,
count(case when payment_label = 'cash'    then 1 end) as cash_trips,
count(case when time_of_day  = 'evening'  then 1 end) as evening_trips
```

**`mart_cohort_retention`**
Groups riders by their first trip month as a cohort and calculates 
what percentage return in each subsequent month. Uses `DATE_TRUNC`, 
`DATEDIFF`, and a self-join pattern across CTEs.

**`mart_vendor_scd`**
Slowly Changing Dimension Type 2 table tracking how vendor metrics 
change month over month. Uses `LEAD()` to derive `effective_to` dates 
and a `CASE WHEN` to set the `is_current` flag.

```sql
lead(pickup_month) over (
    partition by vendor_id
    order by pickup_month
)                          as effective_to,

case
    when effective_to is null then true
    else false
end                        as is_current
```

---

## Data Quality Tests — 22 Tests Passing

---

## Dataset

| Property | Value |
|----------|-------|
| Source | NYC Taxi & Limousine Commission (TLC) |
| URL | https://www.nyc.gov/site/tlc/about/tlc-trip-record-data.page |
| Volume | ~7.1 million yellow taxi trips |
| Format | Parquet → Delta Lake |
| Catalog | `nyc_taxi_project` |
| Schema | `nyc_taxi` |

---

## How to Run

**Prerequisites**
- Python 3.8+
- Databricks workspace with a SQL Warehouse
- dbt Core 1.11+ and dbt-databricks adapter

**Install**
```bash
python -m venv dbt-env
dbt-env\Scripts\activate
pip install dbt-core dbt-databricks
```

**Configure connection**

Create `~/.dbt/profiles.yml`:
```yaml
nyc_taxi_project:
  target: dev
  outputs:
    dev:
      type: databricks
      host: <your-databricks-host>
      http_path: <your-sql-warehouse-http-path>
      token: <your-personal-access-token>
      catalog: nyc_taxi_project
      schema: nyc_taxi
      threads: 1
```

**Run**
```bash
dbt run              # build all models
dbt test             # run all 22 data quality tests
dbt docs generate    # generate documentation
dbt docs serve       # view lineage DAG at localhost:8080
```

---

## Author

Vignesh Menon — Data Engineering Portfolio  
GitHub: https://github.com/VigneshMenon3