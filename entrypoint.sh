#!/bin/bash

# logs
rm -rdf /logs
mkdir logs
chown -R oracle:dba /logs

# Prevent owner issues on mounted folders
chown -R oracle:dba /docker-entrypoint-initdb.d/
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
create or replace directory IMPDP as '/docker-entrypoint-initdb.d/';
exit;
EOL
    echo "Creating IMPDP user..."
	su oracle -c "NLS_LANG=.$CHARACTER_SET $ORACLE_HOME/bin/sqlplus -S / as sysdba @/tmp/impdp_user.sql"  > /logs/impdp_user_creation.log
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

	su oracle -c "NLS_LANG=.$CHARACTER_SET $ORACLE_HOME/bin/sqlplus -S / as sysdba @/tmp/impdp.sql" > /logs/impdp_${DUMP_NAME}_prepare.log
	su oracle -c "NLS_LANG=.$CHARACTER_SET $ORACLE_HOME/bin/impdp IMPDP/IMPDP directory=IMPDP dumpfile=$DUMP_FILE $IMPDP_OPTIONS logfile=${DUMP_NAME}_import.log"
}

impFile() {
	echo "found file $1"
	case "$1" in
		*.sh)     echo "[IMPORT] $0: running $1"; . "$1" ;;
		*.sql)    echo "[IMPORT] $0: running $1"; echo "exit" | su oracle -c "NLS_LANG=.$CHARACTER_SET $ORACLE_HOME/bin/sqlplus -S / as sysdba @$1"; echo ;;
		*.dmp)    echo "[IMPORT] $0: running $1"; impdp $1 ;;
		*)        echo "[IMPORT] $0: ignoring $1" ;;
	esac
}

startDatabase(){
   echo "Starting oracle-xe service..."
   /etc/init.d/oracle-xe start > /logs/oracle_xe_start.log
   echo "oracle-xe service started."
   echo
}

importData(){

    echo "Starting import scripts(*.dmp, *.sql, *.sh) from '/docker-entrypoint-initdb.d':"

    for fn in $(ls -1 /docker-entrypoint-initdb.d/* 2> /dev/null)
	do
		impFile $fn
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

			if [ -z "$CHARACTER_SET" ]; then
				export CHARACTER_SET="AL32UTF8"
			fi

			printf "Setting up:\nprocesses=$processes\nsessions=$sessions\ntransactions=$transactions\n"
			echo "If you want to use different parameters set processes, sessions, transactions env variables and consider this formula:"
			printf "processes=x\nsessions=x*1.1+5\ntransactions=sessions*1.1\n"

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
			importData
		fi

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
