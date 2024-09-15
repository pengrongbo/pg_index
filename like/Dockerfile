FROM postgres:12.7

# Preconfigure debconf to accept changes automatically (non-interactive)
ENV DEBIAN_FRONTEND=noninteractive

# Install pg_trgm extension and avoid interactive prompts
RUN apt-get update && \
    apt-get install -y --no-install-recommends postgresql-contrib && \
    rm -rf /var/lib/apt/lists/*

# Copy initialization script into the container
COPY init.sql /docker-entrypoint-initdb.d/

# Set environment variables
ENV POSTGRES_USER=testuser
ENV POSTGRES_PASSWORD=testpassword
ENV POSTGRES_DB=testdb

EXPOSE 5432