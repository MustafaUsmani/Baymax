# ── Stage 1: Build ──────────────────────────────────────────────────────
FROM python:3.11-slim AS builder

# Install system build dependencies (needed for psycopg2, shapely etc.)
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    libpq-dev \
    build-essential \
    curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

# Copy requirements first for layer caching
COPY requirements.txt .

# Install python dependencies into a local dist folder
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# ── Stage 2: Runtime ────────────────────────────────────────────────────
FROM python:3.11-slim

# Install lightweight runtime system libraries
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq5 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy installed Python packages from builder stage
COPY --from=builder /install /usr/local

# Copy backend application code
COPY app/ ./app/
COPY backend/ ./backend/
COPY populate.py .
COPY requirements.txt .

# Cloud Run requires listening on PORT env variable (defaults to 8080)
ENV PORT=8080

EXPOSE 8080

# Launch FastAPI via uvicorn
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8080", "--workers", "2"]
