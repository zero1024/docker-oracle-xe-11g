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

Run with custom sys password:

    docker run -d -p 1521:1521 -e DEFAULT_SYS_PASS=sYs-p@ssw0rd oracle

Connect database with following setting:

    hostname: localhost
    port: 1521
    sid: xe
    username: system
    password: oracle

Password for SYS & SYSTEM:

    oracle

Auto import of sh sql and dmp files

    docker run -d -p 1521:1521 -v /my/oracle/init/sh_sql_dmp_files:/initdb.d oracle

**In case of using DMP imports dump file should be named like ${IMPORT_SCHEME_NAME}.dmp**
**User credentials for imports are  ${IMPORT_SCHEME_NAME}/${IMPORT_SCHEME_NAME}**

Remap several tablespaces to one

    docker run -d -p 1521:1521 -v /my/oracle/init/sh_sql_dmp_files:/initdb.d - e ${IMPORT_SCHEME_NAME}=tablespace1,tablespace2 oracle

Check database listener status

    docker exec oracle lsnrctl status
    
Import and export (IMPDP dir = /initdb.d)
    


