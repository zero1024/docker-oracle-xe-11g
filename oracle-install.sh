#!/bin/bash

ORA_DEB="oracle-xe_11.2.0-1.0_amd64.deb"

#
# Oracle installer
#
installOracle () {

	cat /${ORA_DEB}a* > /${ORA_DEB}

	rm -f /${ORA_DEB}a*

}

installOracle

dpkg --install /${ORA_DEB}
rm -f /${ORA_DEB}

mv /init.ora       /u01/app/oracle/product/11.2.0/xe/config/scripts
mv /initXETemp.ora /u01/app/oracle/product/11.2.0/xe/config/scripts

mv /u01/app/oracle/product /u01/app/oracle-product

apt-get clean && rm -rf /tmp/* /var/lib/apt/lists/* /var/tmp/*
