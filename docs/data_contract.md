# Data contract

This document defines what each module writes to the shared PostgreSQL database.
It is the agreement between team members: **code may change freely, this contract
may not**. Any change goes through a pull request reviewed by the owners of the
tables involved.

## Conventions

- **Names:** lowercase with underscores (`snake_case`).
- **Units in names:** `_s` seconds, `_m` metres, `_ms` metres per second,
  `_kg` kilograms, `_pct` percent.
- **Time:** seconds since the start of the simulation (`t = 0` at start).
- **Coordinates:** latitude and longitude in decimal degrees (WGS84, as in GPS).
- **Runs:** every result row carries a `run_id`. Never modify or delete another
  member's runs.
- **Storage:** store summaries, not raw per-second traces (Neon free tier: 0.5 GB).

## Overview

| Table | Written by | Read by | Content |
|---|---|---|---|
| `runs` | any module starting a run | everyone | One row per execution |
| `road_segments` | ground_traffic | route_planning, dashboard | The streets of the area |
| `traffic_stats` | ground_traffic | congestion_prediction, route_planning, dashboard | Traffic per street every 5 min |
| `vehicle_trips` | ground_traffic | scenarios, dashboard | One row per vehicle trip |
| `drone_missions` | air_mobility | scenarios, dashboard | One row per drone mission |
| `drone_positions` | air_mobility | dashboard | Drone positions over time |
| `congestion_predictions` | congestion_prediction | route_planning, dashboard | Predicted traffic per street |
| `model_evaluations` | congestion_prediction | dashboard | Accuracy of each model |
| `scenario_indicators` | scenarios | dashboard | Final indicators per run |

## Tables

### `runs`

One row each time someone runs a scenario.

| Column | Type | Description |
|---|---|---|
| `run_id` | integer, generated | Unique identifier |
| `scenario` | text | `S1_ground_only`, `S2_ground_drones` or `S3_ai_optimized` |
| `created_by` | text | Team member's name |
| `created_at` | timestamp | When the run started |
| `status` | text | `running`, `completed` or `failed` |
| `config_snapshot` | JSON | Copy of `config.yaml` used for this run |
| `notes` | text, optional | Free comment |

The `config_snapshot` makes every result reproducible: we always know which
settings produced it.

### `road_segments`

The streets of the study area, written once when the city map is imported.
Not linked to a run.

| Column | Type | Description |
|---|---|---|
| `segment_id` | text | SUMO edge ID |
| `name` | text, optional | Street name |
| `length_m` | number | Length |
| `speed_limit_ms` | number | Speed limit |
| `lanes` | integer | Number of lanes |
| `shape` | JSON | List of `[lat, lon]` points drawing the street |

### `traffic_stats`

Traffic on each street, summarized over each 5-minute interval.

| Column | Type | Description |
|---|---|---|
| `run_id` | integer | → `runs` |
| `segment_id` | text | → `road_segments` |
| `interval_start_s` | integer | Start of the interval |
| `interval_end_s` | integer | End of the interval |
| `vehicle_count` | integer | Vehicles that entered the street |
| `mean_speed_ms` | number | Average speed |
| `occupancy_pct` | number | Share of the street occupied by vehicles |
| `waiting_time_s` | number | Total time vehicles spent stopped |

This is the main training data for the congestion prediction model.

### `vehicle_trips`

One row per completed vehicle trip.

| Column | Type | Description |
|---|---|---|
| `run_id` | integer | → `runs` |
| `vehicle_id` | text | SUMO vehicle ID |
| `vehicle_type` | text | `car` or `delivery_van` |
| `depart_s` | number | Departure time |
| `arrival_s` | number | Arrival time |
| `duration_s` | number | Trip duration |
| `route_length_m` | number | Distance driven |
| `waiting_time_s` | number | Time spent stopped |

`delivery_van` trips are the ones scenarios S2 and S3 can move to drones.

### `drone_missions`

One row per drone mission, including rejected ones.

| Column | Type | Description |
|---|---|---|
| `run_id` | integer | → `runs` |
| `mission_id` | text | From `config.yaml` (e.g. `M001`) |
| `mission_type` | text | `parcel`, `medical` or `emergency` |
| `hub_id` | text | Departure hub |
| `dest_lat`, `dest_lon` | number | Destination |
| `payload_kg` | number | Weight carried |
| `status` | text | `completed` or `rejected` |
| `reject_reason` | text, optional | e.g. `payload_too_heavy`, `out_of_range` |
| `depart_s` | number | Take-off time |
| `arrival_s` | number, optional | Delivery time (empty if rejected) |
| `distance_m` | number, optional | Distance flown, including detours |

### `drone_positions`

Drone positions, one row every 5 seconds of flight.

| Column | Type | Description |
|---|---|---|
| `run_id` | integer | → `runs` |
| `mission_id` | text | → `drone_missions` |
| `t_s` | number | Time |
| `lat`, `lon` | number | Position |
| `altitude_m` | number | Altitude |

### `congestion_predictions`

What the model predicts for each street, next to what actually happened.

| Column | Type | Description |
|---|---|---|
| `run_id` | integer | → `runs` |
| `segment_id` | text | → `road_segments` |
| `interval_start_s` | integer | Interval predicted |
| `model_name` | text | e.g. `random_forest_v1` |
| `predicted_speed_ms` | number | Predicted average speed |
| `actual_speed_ms` | number, optional | Real value, when known |

### `model_evaluations`

Accuracy of each trained model.

| Column | Type | Description |
|---|---|---|
| `model_name` | text | Model identifier |
| `trained_at` | timestamp | When it was trained |
| `metric` | text | e.g. `MAE`, `RMSE`, `R2` |
| `value` | number | Score |

### `scenario_indicators`

The final numbers that compare the scenarios.

| Column | Type | Description |
|---|---|---|
| `run_id` | integer | → `runs` |
| `indicator` | text | e.g. `mean_travel_time_s`, `mean_delivery_time_s` |
| `value` | number | Value |
| `unit` | text | e.g. `s`, `m`, `pct` |

Storing indicators as rows means adding a new indicator never requires
changing the table.

## Changing this contract

1. Open a pull request that edits this file **and** `database/schema.sql`.
2. The owners of the affected tables must approve it.
3. Announce the change to the team once it is merged.