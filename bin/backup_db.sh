#!/bin/bash

cd /opt/infoservant.com/sql && sudo -u postgres /usr/pgsql-9.2/bin/pg_dump scotch_egg -f scotch_egg.txt.$(date "+%FT%T")
