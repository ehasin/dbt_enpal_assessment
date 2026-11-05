#!/bin/bash
set -euo pipefail

# Wait until PostgreSQL is ready
until pg_isready -h db -U admin; do
  echo "Waiting for database connection..."
  sleep 2
done

# Replace every table in one transaction, so loading twice changes nothing.
# Any error rolls back, keeps the previous data and exits non-zero.
tables="activity activity_types deal_changes fields stages users"

for table_name in $tables; do
  echo "\\echo Loading /raw_data/$table_name.csv into table $table_name..."
  echo "TRUNCATE TABLE $table_name;"
  echo "\\COPY $table_name FROM '/raw_data/$table_name.csv' DELIMITER ',' CSV HEADER;"
done | psql -h db -U admin -d postgres --quiet --set ON_ERROR_STOP=1 --single-transaction --file=-

echo "Data loading completed."
