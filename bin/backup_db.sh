#!/bin/bash

set -e

cd /opt/infoservant.com/sql

FILE=scotch_egg.txt.$(date "+%FT%T")
sudo -u postgres /usr/pgsql-9.2/bin/pg_dump scotch_egg -f $FILE
gzip $FILE

# Keep three days of backups
ls scotch_egg.txt.201* | grep -v -f <(ls scotch_egg.txt.201* | sort | tail -72) | xargs -r rm
