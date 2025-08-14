# Multi-stage build for BrainSAIT Healthcare Platform
FROM python:3.11-slim as base

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    DEBIAN_FRONTEND=noninteractive \
    LC_ALL=C.UTF-8 \
    LANG=C.UTF-8

# Install system dependencies for multilingual support
RUN apt-get update && apt-get install -y \
    build-essential \
    curl \
    git \
    libpq-dev \
    pkg-config \
    gcc \
    g++ \
    # Arabic and multilingual font support
    fonts-noto \
    fonts-noto-cjk \
    fonts-noto-color-emoji \
    fonts-liberation \
    fontconfig \
    # Audio processing for TTS/ASR
    ffmpeg \
    libsndfile1 \
    # Other utilities
    wget \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user for security
RUN groupadd -r brainsait && useradd -r -g brainsait brainsait

# Set work directory
WORKDIR /app

# Copy requirements and install dependencies
COPY backend/requirements.txt /app/
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# Development stage
FROM base as development

# Install development dependencies
RUN pip install --no-cache-dir pytest pytest-asyncio black flake8 mypy

# Copy application code
COPY backend/ /app/
RUN chown -R brainsait:brainsait /app

USER brainsait

# Expose port
EXPOSE 8000

# Command for development
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000", "--reload"]

# Production stage
FROM base as production

# Copy application code
COPY backend/ /app/

# Create required directories
RUN mkdir -p /app/logs /app/models /app/static && \
    chown -R brainsait:brainsait /app

# Install fonts for Arabic and other languages
COPY docker/fonts/ /usr/share/fonts/truetype/
RUN fc-cache -fv

# Switch to non-root user
USER brainsait

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# Expose port
EXPOSE 8000

# Production command with Gunicorn
CMD ["gunicorn", "main:app", "-w", "4", "-k", "uvicorn.workers.UvicornWorker", "--bind", "0.0.0.0:8000", "--access-logfile", "-", "--error-logfile", "-", "--log-level", "info"]