# Use official PostgreSQL image from Docker Hub
FROM postgres:14

# Switch to root for installing extensions
USER root

# Install PostgreSQL contrib package for pg_trgm and pg_stat_statements
RUN apt-get update && apt-get install -y postgresql-contrib

# Switch back to the postgres user
USER postgres

# Set environment variables
ENV POSTGRES_DB=test_db
ENV POSTGRES_USER=postgres
ENV POSTGRES_PASSWORD=yourpassword

# Expose default PostgreSQL port
EXPOSE 5432

# Add initialization script
COPY init.sql /docker-entrypoint-initdb.d/
