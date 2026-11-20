# Start from an official image: Linux + Python 3.12
FROM python:3.12-slim

# System libraries SUMO needs to run (the slim image doesn't include them)
RUN apt-get update && apt-get install -y --no-install-recommends \
        libgl1 libx11-6 libxext6 libxrender1 libatomic1 libexpat1 \
    && rm -rf /var/lib/apt/lists/*

# Show Python output immediately and don't create .pyc files
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    SUMO_HOME=/usr/local/lib/python3.12/site-packages/sumo

# Folder inside the container where the project lives
WORKDIR /app

# Install the libraries first. Docker caches this step,
# so later builds are fast unless requirements.txt changes.
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Then copy the project code
COPY . .