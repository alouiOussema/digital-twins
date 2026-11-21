-- ---------------------------------------------------------------
-- Database schema of the digital twin.
-- Translates docs/data_contract.md into PostgreSQL tables.
-- Safe to run several times: existing tables are left untouched.
-- ---------------------------------------------------------------

-- One row per execution of a scenario
CREATE TABLE IF NOT EXISTS runs (
    run_id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    scenario        TEXT        NOT NULL,
    created_by      TEXT        NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    status          TEXT        NOT NULL DEFAULT 'running'
                    CHECK (status IN ('running', 'completed', 'failed')),
    config_snapshot JSONB,
    notes           TEXT
);

-- The streets of the study area (written once, not linked to a run)
CREATE TABLE IF NOT EXISTS road_segments (
    segment_id      TEXT PRIMARY KEY,
    name            TEXT,
    length_m        DOUBLE PRECISION NOT NULL CHECK (length_m > 0),
    speed_limit_ms  DOUBLE PRECISION CHECK (speed_limit_ms > 0),
    lanes           INTEGER CHECK (lanes >= 1),
    shape           JSONB
);

-- Traffic on each street, summarized per interval
CREATE TABLE IF NOT EXISTS traffic_stats (
    run_id           BIGINT  NOT NULL REFERENCES runs (run_id) ON DELETE CASCADE,
    segment_id       TEXT    NOT NULL REFERENCES road_segments (segment_id),
    interval_start_s INTEGER NOT NULL,
    interval_end_s   INTEGER NOT NULL,
    vehicle_count    INTEGER CHECK (vehicle_count >= 0),
    mean_speed_ms    DOUBLE PRECISION CHECK (mean_speed_ms >= 0),
    occupancy_pct    DOUBLE PRECISION CHECK (occupancy_pct BETWEEN 0 AND 100),
    waiting_time_s   DOUBLE PRECISION CHECK (waiting_time_s >= 0),
    PRIMARY KEY (run_id, segment_id, interval_start_s),
    CHECK (interval_end_s > interval_start_s)
);

-- The AI module reads traffic street by street, over time
CREATE INDEX IF NOT EXISTS idx_traffic_stats_segment_time
    ON traffic_stats (segment_id, interval_start_s);

-- One row per completed vehicle trip
CREATE TABLE IF NOT EXISTS vehicle_trips (
    run_id          BIGINT NOT NULL REFERENCES runs (run_id) ON DELETE CASCADE,
    vehicle_id      TEXT   NOT NULL,
    vehicle_type    TEXT   NOT NULL CHECK (vehicle_type IN ('car', 'delivery_van')),
    depart_s        DOUBLE PRECISION NOT NULL,
    arrival_s       DOUBLE PRECISION NOT NULL,
    duration_s      DOUBLE PRECISION NOT NULL CHECK (duration_s >= 0),
    route_length_m  DOUBLE PRECISION CHECK (route_length_m >= 0),
    waiting_time_s  DOUBLE PRECISION CHECK (waiting_time_s >= 0),
    PRIMARY KEY (run_id, vehicle_id)
);

-- One row per drone mission, including rejected ones
CREATE TABLE IF NOT EXISTS drone_missions (
    run_id          BIGINT NOT NULL REFERENCES runs (run_id) ON DELETE CASCADE,
    mission_id      TEXT   NOT NULL,
    mission_type    TEXT   NOT NULL CHECK (mission_type IN ('parcel', 'medical', 'emergency')),
    hub_id          TEXT   NOT NULL,
    dest_lat        DOUBLE PRECISION NOT NULL,
    dest_lon        DOUBLE PRECISION NOT NULL,
    payload_kg      DOUBLE PRECISION NOT NULL CHECK (payload_kg >= 0),
    status          TEXT   NOT NULL CHECK (status IN ('completed', 'rejected')),
    reject_reason   TEXT,
    depart_s        DOUBLE PRECISION NOT NULL,
    arrival_s       DOUBLE PRECISION,
    distance_m      DOUBLE PRECISION CHECK (distance_m >= 0),
    PRIMARY KEY (run_id, mission_id),
    -- a completed mission has an arrival time, a rejected one has a reason
    CHECK (status = 'rejected' OR arrival_s IS NOT NULL),
    CHECK (status = 'completed' OR reject_reason IS NOT NULL)
);

-- Drone positions over time
CREATE TABLE IF NOT EXISTS drone_positions (
    run_id          BIGINT NOT NULL,
    mission_id      TEXT   NOT NULL,
    t_s             DOUBLE PRECISION NOT NULL,
    lat             DOUBLE PRECISION NOT NULL,
    lon             DOUBLE PRECISION NOT NULL,
    altitude_m      DOUBLE PRECISION NOT NULL CHECK (altitude_m >= 0),
    PRIMARY KEY (run_id, mission_id, t_s),
    FOREIGN KEY (run_id, mission_id)
        REFERENCES drone_missions (run_id, mission_id) ON DELETE CASCADE
);

-- Predicted traffic per street, next to the real value
CREATE TABLE IF NOT EXISTS congestion_predictions (
    run_id             BIGINT  NOT NULL REFERENCES runs (run_id) ON DELETE CASCADE,
    segment_id         TEXT    NOT NULL REFERENCES road_segments (segment_id),
    interval_start_s   INTEGER NOT NULL,
    model_name         TEXT    NOT NULL,
    predicted_speed_ms DOUBLE PRECISION NOT NULL,
    actual_speed_ms    DOUBLE PRECISION,
    PRIMARY KEY (run_id, segment_id, interval_start_s, model_name)
);

-- Accuracy of each trained model
CREATE TABLE IF NOT EXISTS model_evaluations (
    evaluation_id   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    model_name      TEXT        NOT NULL,
    trained_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    metric          TEXT        NOT NULL,
    value           DOUBLE PRECISION NOT NULL,
    UNIQUE (model_name, trained_at, metric)
);

-- Final indicators that compare the scenarios
CREATE TABLE IF NOT EXISTS scenario_indicators (
    run_id          BIGINT NOT NULL REFERENCES runs (run_id) ON DELETE CASCADE,
    indicator       TEXT   NOT NULL,
    value           DOUBLE PRECISION NOT NULL,
    unit            TEXT,
    PRIMARY KEY (run_id, indicator)
);