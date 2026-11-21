"""Access to the shared PostgreSQL database.

Modules use these functions instead of writing their own connection code:
    start_run / finish_run   create and close a run
    write_table              save a pandas DataFrame into a table
    read_query               load the result of a SQL query as a DataFrame

Run this file directly to create the tables and test the connection:
    python -m src.shared.database
"""

import json
from functools import lru_cache

import pandas as pd
from sqlalchemy import create_engine, text
from sqlalchemy.engine import Engine

from src.shared.settings import SCHEMA_FILE, get_db_settings, get_team_member


@lru_cache
def get_engine() -> Engine:
    """Return the connection to the database (created once, then reused).

    pool_pre_ping checks a connection before using it. Neon suspends the
    database after a few idle minutes, which silently closes old connections.
    """
    return create_engine(get_db_settings().url, pool_pre_ping=True)


def create_tables() -> None:
    """Create the tables from database/schema.sql (existing tables are kept)."""
    sql = SCHEMA_FILE.read_text(encoding="utf-8")
    # The raw driver connection runs a whole script of several statements at once
    raw = get_engine().raw_connection()
    try:
        with raw.cursor() as cursor:
            cursor.execute(sql)
        raw.commit()
    finally:
        raw.close()


def start_run(scenario: str, config: dict | None = None, notes: str | None = None) -> int:
    """Register a new run and return its run_id. Call this before writing results."""
    query = text(
        """
        INSERT INTO runs (scenario, created_by, config_snapshot, notes)
        VALUES (:scenario, :created_by, CAST(:config AS JSONB), :notes)
        RETURNING run_id
        """
    )
    with get_engine().begin() as conn:
        return conn.execute(
            query,
            {
                "scenario": scenario,
                "created_by": get_team_member(),
                "config": json.dumps(config) if config is not None else None,
                "notes": notes,
            },
        ).scalar_one()


def finish_run(run_id: int, status: str = "completed") -> None:
    """Mark a run as 'completed' or 'failed'."""
    with get_engine().begin() as conn:
        conn.execute(
            text("UPDATE runs SET status = :status WHERE run_id = :run_id"),
            {"status": status, "run_id": run_id},
        )


def write_table(df: pd.DataFrame, table: str) -> int:
    """Append the rows of a DataFrame to a table. Returns the number of rows written.

    The DataFrame columns must have the same names as the table columns
    (see docs/data_contract.md).
    """
    if df.empty:
        return 0
    df.to_sql(table, get_engine(), if_exists="append", index=False,
              method="multi", chunksize=1000)
    return len(df)


def read_query(query: str, params: dict | None = None) -> pd.DataFrame:
    """Run a SELECT query and return the result as a DataFrame.

    Use :name placeholders for values, never put values in the string yourself:
        read_query("SELECT * FROM runs WHERE scenario = :s", {"s": "S1_ground_only"})
    """
    with get_engine().connect() as conn:
        return pd.read_sql(text(query), conn, params=params)


if __name__ == "__main__":
    # Checkpoint of phase 2: create the tables, write a row, read it back
    print("1. Creating tables...")
    create_tables()
    tables = read_query(
        "SELECT table_name FROM information_schema.tables "
        "WHERE table_schema = 'public' ORDER BY table_name"
    )
    print(f"   {len(tables)} tables: {', '.join(tables['table_name'])}")

    print("2. Writing a test run...")
    run_id = start_run("S1_ground_only", notes="connection test")
    write_table(
        pd.DataFrame([{"run_id": run_id, "indicator": "test_value", "value": 42.0, "unit": "s"}]),
        "scenario_indicators",
    )
    finish_run(run_id)

    print("3. Reading it back...")
    print(read_query(
        "SELECT r.run_id, r.created_by, r.status, i.indicator, i.value "
        "FROM runs r JOIN scenario_indicators i USING (run_id) WHERE r.run_id = :id",
        {"id": run_id},
    ).to_string(index=False))

    print("4. Cleaning up the test run...")
    with get_engine().begin() as conn:
        conn.execute(text("DELETE FROM runs WHERE run_id = :id"), {"id": run_id})

    print("Database OK")