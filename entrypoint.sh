#!/bin/bash

# logs
rm -rdf /logs
mkdir logs
chown -R oracle:dba /logs

# Prevent owner issues on mounted folders
chown -R oracle:dba /initdb/ || :
chown -R oracle:dba /sql/ || :
chown -R oracle:dba /sql-patches/ || :
chown -R oracle:dba /u01/app/oracle
rm -f /u01/app/oracle/product
ln -s /u01/app/oracle-product /u01/app/oracle/product
# Update hostname
sed -i -E "s/HOST = [^)]+/HOST = $HOSTNAME/g" /u01/app/oracle/product/11.2.0/xe/network/admin/listener.ora
sed -i -E "s/PORT = [^)]+/PORT = 1521/g" /u01/app/oracle/product/11.2.0/xe/network/admin/listener.ora
echo "export ORACLE_HOME=/u01/app/oracle/product/11.2.0/xe" > /etc/profile.d/oracle-xe.sh
echo "export PATH=\$ORACLE_HOME/bin:\$PATH" >> /etc/profile.d/oracle-xe.sh
echo "export ORACLE_SID=XE" >> /etc/profile.d/oracle-xe.sh
. /etc/profile


impdpUserCreation () {
	cat > /tmp/impdp_user.sql << EOL
CREATE USER IMPDP IDENTIFIED BY IMPDP;
ALTER USER IMPDP ACCOUNT UNLOCK;
GRANT dba TO IMPDP WITH ADMIN OPTION;
create or replace directory IMPDP as '/initdb/';
exit;
EOL
    echo "Creating IMPDP user..."
	su oracle -c "$ORACLE_HOME/bin/sqlplus -S / as sysdba @/tmp/impdp_user.sql"  > /logs/impdp_user_creation.log
	echo "IMPDP user created."
	echo 
}


impdp () {
	DUMP_FILE=$(basename "$1")
	DUMP_NAME=${DUMP_FILE%.dmp}
	cat > /tmp/impdp.sql << EOL
create tablespace $DUMP_NAME datafile '/u01/app/oracle/oradata/$DUMP_NAME.dbf' size 1000M autoextend on next 100M maxsize unlimited;
create user $DUMP_NAME identified by $DUMP_NAME default tablespace $DUMP_NAME;
alter user $DUMP_NAME quota unlimited on $DUMP_NAME;
alter user $DUMP_NAME default role all;
grant connect, resource to $DUMP_NAME;
exit;
EOL

    REMAP_TABLESPACE=""
    eval tablespaces='$'$DUMP_NAME

    if [ ! -z "$tablespaces" ] ; then
        export IFS=","
        for word in $tablespaces; do
            REMAP_TABLESPACE="$REMAP_TABLESPACE REMAP_TABLESPACE=$word:$DUMP_NAME"
        done
        echo "Tablespace remap rule for $DUMP_NAME - $REMAP_TABLESPACE"
    fi

	su oracle -c "$ORACLE_HOME/bin/sqlplus -S / as sysdba @/tmp/impdp.sql" > /initdb/${DUMP_NAME}_import_prepare.log
	su oracle -c "$ORACLE_HOME/bin/impdp IMPDP/IMPDP directory=IMPDP dumpfile=$DUMP_FILE $REMAP_TABLESPACE $IMPDP_OPTIONS logfile=${DUMP_NAME}_import.log PARTITION_OPTIONS=merge 2>&1" >/dev/null
}

sql() {
 echo "exit" | su oracle -c "$ORACLE_HOME/bin/sqlplus -S / as sysdba @$1" > ${1%.sql}_sql_import.log
}

sqlPatch() {
 cd $1
 echo "exit" | su oracle -c "$ORACLE_HOME/bin/sqlplus -S / as sysdba @start.sql" > ${1%.sql}_sql_import.log
 cd ../
}

impFile() {
	echo "found file $1"
	case "$1" in
		*.sh)     echo "[IMPORT] running $1"; . "$1" ;;
		*.sql)    echo "[IMPORT] running $1"; sql "$1" ;;
		*.dmp)    echo "[IMPORT] running $1"; impdp $1 ;;
		*)        echo "[IMPORT] ignoring $1" ;;
	esac
}

startDatabase(){
   echo "Starting oracle-xe service..."
   /etc/init.d/oracle-xe start > /logs/oracle_xe_start.log
   echo "oracle-xe service started."
   echo
}

importInitialData(){

    echo "Starting import scripts(*.dmp, *.sql, *.sh) from '/initdb':"
    echo "Import logs will be available in '/initdb'"

    for fn in $(ls -1 /initdb/* 2> /dev/null)
	do
		impFile $fn
	done

	echo "Import finished"
	echo

}

importSqlFiles(){

    echo "Starting import sql scripts from '/sql':"
    echo "Import logs will be available in '/sql'"

    for fn in $(ls -1 /sql/*.sql 2> /dev/null)
	do
	    echo "found file $fn"
		echo "[IMPORT] running $fn"; sql $fn
	done

	echo "Import finished"
	echo

}

importSqlPatches(){

    echo "Starting import sql patches from '/sql-patches':"
    echo "Import logs will be available in '/sql-patches'"

    for fn in $(ls -1 -d /sql-patches/*/ 2> /dev/null)
	do
	    echo "found patch $fn"
		echo "[IMPORT] running $fn"; sqlPatch $fn
	done

	echo "Import finished"
	echo

}

case "$1" in
	'')

        echo "Starting database..."
        echo "Check detailed logs in /logs dir"
        echo

		#Check for mounted database files
		if [ "$(ls -A /u01/app/oracle/oradata 2> /dev/null)" ]; then

			echo "Found files in /u01/app/oracle/oradata. Using them instead of initial database"
			echo 

			echo "XE:$ORACLE_HOME:N" >> /etc/oratab
			chown oracle:dba /etc/oratab
			chown 664 /etc/oratab
			printf "ORACLE_DBENABLED=false\nLISTENER_PORT=1521\nHTTP_PORT=8080\nCONFIGURE_RUN=true\n" > /etc/default/oracle-xe
			rm -rf /u01/app/oracle-product/11.2.0/xe/dbs
			ln -s /u01/app/oracle/dbs /u01/app/oracle-product/11.2.0/xe/dbs
			startDatabase
		else
			echo "It's a first start. Database is not initialized. Initializing database."

			printf "Setting up:\nprocesses=$processes\nsessions=$sessions\ntransactions=$transactions\n"

			mv /u01/app/oracle-product/11.2.0/xe/dbs /u01/app/oracle/dbs
			ln -s /u01/app/oracle/dbs /u01/app/oracle-product/11.2.0/xe/dbs

			#Setting up processes, sessions, transactions.
			sed -i -E "s/processes=[^)]+/processes=$processes/g" /u01/app/oracle/product/11.2.0/xe/config/scripts/init.ora
			sed -i -E "s/processes=[^)]+/processes=$processes/g" /u01/app/oracle/product/11.2.0/xe/config/scripts/initXETemp.ora
			
			sed -i -E "s/sessions=[^)]+/sessions=$sessions/g" /u01/app/oracle/product/11.2.0/xe/config/scripts/init.ora
			sed -i -E "s/sessions=[^)]+/sessions=$sessions/g" /u01/app/oracle/product/11.2.0/xe/config/scripts/initXETemp.ora

			sed -i -E "s/transactions=[^)]+/transactions=$transactions/g" /u01/app/oracle/product/11.2.0/xe/config/scripts/init.ora
			sed -i -E "s/transactions=[^)]+/transactions=$transactions/g" /u01/app/oracle/product/11.2.0/xe/config/scripts/initXETemp.ora

			printf 8080\\n1521\\n${DEFAULT_SYS_PASS}\\n${DEFAULT_SYS_PASS}\\ny\\n | /etc/init.d/oracle-xe configure > /logs/oracle_xe_configure.log
			echo "Setting sys/system passwords"
			echo  alter user sys identified by \"$DEFAULT_SYS_PASS\"\; | su oracle -s /bin/bash -c "$ORACLE_HOME/bin/sqlplus -s / as sysdba" > /dev/null 2>&1
   			echo  alter user system identified by \"$DEFAULT_SYS_PASS\"\; | su oracle -s /bin/bash -c "$ORACLE_HOME/bin/sqlplus -s / as sysdba" > /dev/null 2>&1

			echo "Database pre-initialized."
			echo

			startDatabase
			impdpUserCreation
			importInitialData
		fi

		importSqlFiles
		importSqlPatches

        echo "Database started and will be ready within a few seconds (check container health)."

		##
		## Workaround for graceful shutdown. ....ing oracle... ‿( ́ ̵ _-`)‿
		##
		while [ "$END" == '' ]; do
			sleep 1
			trap "/etc/init.d/oracle-xe stop && END=1" INT TERM
		done
		;;

	*)
		echo "Database is not configured. Please run /etc/init.d/oracle-xe configure if needed."
		exec "$@"
		;;
esac
