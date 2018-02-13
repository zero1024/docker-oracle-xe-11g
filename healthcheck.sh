#!/bin/bash

CHECK=$($ORACLE_HOME/bin/sqlplus -s system/oracle <<END
  set pagesize 0 feedback off verify off heading off echo off;
  select count(*) from ALL_TABLES;
  exit;
END
)

# File check
if ! [ -f started ] 2>/dev/null; then
  exit 1
fi

# Exist table check
if [ ${CHECK} -gt 0 ]; then
  echo "Healthy"
  exit 0
else
  exit 1
fi