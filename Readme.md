# AI-Enhanced Digital Twin for Smart City and Drone Mobility

A virtual copy of a Cergy district that simulates road traffic and delivery drones
together, predicts congestion with AI, and compares mobility strategies on a dashboard.

**Main question:** if some deliveries move from vans to drones, what happens to
congestion, delivery time and overall mobility efficiency?

CY Tech project, supervised by Prof. Besma Zeddini.

## Team

| Member | Role | Module |
|---|---|---|
| Name 1 | Traffic simulation | `src/ground_traffic/` |
| Name 2 | Drone simulation | `src/air_mobility/` |
| Name 3 | Congestion prediction (AI) | `src/congestion_prediction/` |
| Name 4 | Route planning and scenarios | `src/route_planning/`, `src/scenarios/` |
| Name 5 | Integration, database, dashboard | `src/shared/`, `src/dashboard/` |

## Tech stack

- **Simulation:** SUMO (traffic), Python (drones)
- **Data and AI:** pandas, NumPy, scikit-learn
- **Route optimization:** NetworkX, OR-Tools
- **Map data:** OpenStreetMap via OSMnx
- **Database:** PostgreSQL, hosted on Neon (shared by the whole team)
- **Dashboard:** Streamlit, Plotly
- **Environment:** Docker

## Getting started

### 1. Install

- [Docker Desktop](https://www.docker.com/products/docker-desktop/)
- [Git](https://git-scm.com/)

You don't need to install Python or any library: everything runs inside Docker.

### 2. Get the code

```
git clone https://github.com/YOUR_USERNAME/digital-twin.git
cd digital-twin
```

### 3. Set up the database connection

Copy the template, then fill in the values you received privately from the team:

```
cp .env.example .env        # Mac/Linux
copy .env.example .env      # Windows
```

Never commit `.env`: it contains the database password.

### 4. Start the environment

Make sure Docker Desktop is running, then:

```
docker compose up -d --build
```

The first build takes a few minutes.

### 5. Check everything works

```
docker compose exec app bash
sumo --version
python -c "import pandas, osmnx, sklearn, streamlit; print('All good')"
exit
```

## Daily commands

| Command | What it does |
|---|---|
| `docker compose up -d` | Start the environment |
| `docker compose exec app bash` | Open a terminal inside the container |
| `docker compose down` | Stop the environment |
| `docker compose up -d --build` | Rebuild after changing `requirements.txt` |

## How we work

1. **Never push directly to `main`.** Create a branch for each task:
   `git checkout -b feature/short-description`
2. Commit often, with clear messages.
3. Push your branch and open a **pull request** on GitHub.
4. Another team member reviews it before it's merged into `main`.

## Project structure

```
src/
├── shared/                  settings and database connection
├── ground_traffic/          SUMO traffic simulation
├── air_mobility/            drone simulation
├── congestion_prediction/   AI model
├── route_planning/          routing for vehicles and drones
├── scenarios/               scenarios S1, S2, S3 and indicators
└── dashboard/               Streamlit interface
```

## Scenarios

| Scenario | Description |
|---|---|
| S1 | Conventional ground transport, no drones |
| S2 | Ground transport plus drone parcel delivery |
| S3 | AI traffic prediction and optimized ground–air mobility |