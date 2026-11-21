"""Project settings: reads config.yaml (shared values) and .env (private values).

Every module gets its settings from here, never by opening the files itself.
"""

import os
from dataclasses import dataclass
from functools import lru_cache
from pathlib import Path

import yaml
from dotenv import load_dotenv
from sqlalchemy.engine import URL

# Root of the project: this file is in src/shared/, so two levels up
PROJECT_ROOT = Path(__file__).resolve().parents[2]
CONFIG_FILE = PROJECT_ROOT / "config.yaml"
SCHEMA_FILE = PROJECT_ROOT / "database" / "schema.sql"

# Inside Docker, .env is already loaded by docker-compose.
# Outside Docker, this line loads it. Existing values are not overwritten.
load_dotenv(PROJECT_ROOT / ".env")


@lru_cache
def load_config() -> dict:
    """Return the content of config.yaml as a dictionary (read once, then cached)."""
    with open(CONFIG_FILE, encoding="utf-8") as f:
        return yaml.safe_load(f)


def _require_env(name: str) -> str:
    """Return an environment variable, or stop with a clear message if it's missing."""
    value = os.getenv(name)
    if not value:
        raise RuntimeError(
            f"Missing setting '{name}'. Check that it is defined in your .env file "
            f"(see .env.example)."
        )
    return value


@dataclass(frozen=True)
class DatabaseSettings:
    host: str
    port: int
    name: str
    user: str
    password: str
    sslmode: str

    @property
    def url(self) -> URL:
        """Connection address for SQLAlchemy.

        URL.create escapes special characters in the password,
        which would break a hand-written connection string.
        """
        return URL.create(
            drivername="postgresql+psycopg",
            username=self.user,
            password=self.password,
            host=self.host,
            port=self.port,
            database=self.name,
            query={"sslmode": self.sslmode},
        )


@lru_cache
def get_db_settings() -> DatabaseSettings:
    """Read the database connection settings from the environment (.env)."""
    return DatabaseSettings(
        host=_require_env("DB_HOST"),
        port=int(os.getenv("DB_PORT", "5432")),
        name=_require_env("DB_NAME"),
        user=_require_env("DB_USER"),
        password=_require_env("DB_PASSWORD"),
        sslmode=os.getenv("DB_SSLMODE", "require"),
    )


def get_team_member() -> str:
    """Name of the person running the code, saved in each run."""
    return os.getenv("TEAM_MEMBER", "unknown")