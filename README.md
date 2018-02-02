docker-oracle-xe-11g
============================

Oracle Express Edition 11g Release 2 on Ubuntu 14.04.1 LTS

Run with 1521 ports opened:

    docker run -d -p 1521:1521 oracle

Run with customization of processes, sessions, transactions
This customization is needed on the database initialization stage.

    ##Consider this formula before customizing:
    #processes=x
    #sessions=x*1.1+5
    #transactions=sessions*1.1
    docker run -d -p 1521:1521 -v /my/oracle/data:/u01/app/oracle\
    -e processes=1000 \
    -e sessions=1105 \
    -e transactions=1215 \
    oracle

Connect database with following setting:

    hostname: localhost
    port: 1521
    sid: xe
    username: system (or sys)
    password: oracle

Initial import of sh sql and dmp files (happens only once)

    docker run -d -p 1521:1521 -v /my/oracle/init/sh_sql_dmp_files:/initdb oracle

**In case of using DMP imports dump file should be named like ${IMPORT_SCHEME_NAME}.dmp**
**User credentials for imports are  ${IMPORT_SCHEME_NAME}/${IMPORT_SCHEME_NAME}**

Remap several tablespaces to one

    docker run -d -p 1521:1521 -v /my/oracle/init/sh_sql_dmp_files:/initdb - e ${IMPORT_SCHEME_NAME}=tablespace1,tablespace2 oracle

Import of sql files (happens every time when needed)

    docker run -d -p 1521:1521 -v /my/oracle/init/sql_files:/sql oracle
