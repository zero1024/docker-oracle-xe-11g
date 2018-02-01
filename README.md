docker-oracle-xe-11g
============================

Oracle Express Edition 11g Release 2 on Ubuntu 14.04.1 LTS

Run with 8080 and 1521 ports opened:

    docker run -d -p 8080:8080 -p 1521:1521 oracle11

Run with customization of processes, sessions, transactions
This customization is needed on the database initialization stage.

    ##Consider this formula before customizing:
    #processes=x
    #sessions=x*1.1+5
    #transactions=sessions*1.1
    docker run -d -p 8080:8080 -p 1521:1521 -v /my/oracle/data:/u01/app/oracle\
    -e processes=1000 \
    -e sessions=1105 \
    -e transactions=1215 \
    oracle11

Run with custom sys password:

    docker run -d -p 8080:8080 -p 1521:1521 -e DEFAULT_SYS_PASS=sYs-p@ssw0rd oracle11

Connect database with following setting:

    hostname: localhost
    port: 1521
    sid: xe
    username: system
    password: oracle

Password for SYS & SYSTEM:

    oracle

Connect to Oracle Application Express web management console with following settings:

    http://localhost:8080/apex
    workspace: INTERNAL
    user: ADMIN
    password: oracle

Apex upgrade up to v 5.*

    docker run -it --rm --volumes-from ${DB_CONTAINER_NAME} --link ${DB_CONTAINER_NAME}:oracle-database -e PASS=YourSYSPASS sath89/apex install
Details could be found here: https://github.com/MaksymBilenko/docker-oracle-apex

Auto import of sh sql and dmp files

    docker run -d -p 8080:8080 -p 1521:1521 -v /my/oracle/data:/u01/app/oracle -v /my/oracle/init/sh_sql_dmp_files:/docker-entrypoint-initdb.d sath89/oracle-xe-11g

**In case of using DMP imports dump file should be named like ${IMPORT_SCHEME_NAME}.dmp**
**User credentials for imports are  ${IMPORT_SCHEME_NAME}/${IMPORT_SCHEME_NAME}**

Check database listener status

    docker exec oracle lsnrctl status



