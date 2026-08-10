# ═══════════════════════════════════════════════════════════════════
# CP2 — Containerization (production-ready)
# ═══════════════════════════════════════════════════════════════════

# --- Stage 1: Builder ---
FROM python:3.11-slim AS builder

WORKDIR /build

COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# --- Stage 2: Runtime ---
FROM python:3.11-slim AS runtime

# Copy installed dependencies from builder
COPY --from=builder /install /usr/local

WORKDIR /app

# Create non-root user
RUN useradd --create-home --uid 10001 appuser

# Copy source code (requirements already installed via builder stage)
COPY app ./app
COPY utils ./utils

# Switch to non-root user
USER appuser

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health').read()" || exit 1

CMD ["sh", "-c", "uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"]
