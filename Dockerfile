FROM ubuntu:14.04

MAINTAINER Oleg Perekhod <poa1024@gmail.com>

# get rid of the message: "debconf: unable to initialize frontend: Dialog"
ENV DEBIAN_FRONTEND noninteractive

ADD chkconfig /sbin/chkconfig
ADD oracle-install.sh /oracle-install.sh
ADD init.ora /
ADD initXETemp.ora /

ADD oracle-xe_11.2.0-1.0_amd64.debaa /
ADD oracle-xe_11.2.0-1.0_amd64.debab /
ADD oracle-xe_11.2.0-1.0_amd64.debac /

# Prepare to install Oracle
RUN apt-get update && apt-get install -y -q libaio1 net-tools bc curl rlwrap && \
apt-get clean && \
rm -rf /tmp/* /var/lib/apt/lists/* /var/tmp/* &&\
ln -s /usr/bin/awk /bin/awk &&\
mkdir /var/lock/subsys &&\
chmod 755 /sbin/chkconfig &&\
/oracle-install.sh

# see issue #1
ENV ORACLE_HOME /u01/app/oracle/product/11.2.0/xe
ENV PATH $ORACLE_HOME/bin:$PATH
ENV ORACLE_SID=XE
ENV DEFAULT_SYS_PASS oracle

EXPOSE 1521
EXPOSE 8080

ENV processes 500
ENV sessions 555
ENV transactions 610

ADD entrypoint.sh /
ADD healthcheck.sh /
ENTRYPOINT ["/entrypoint.sh"]
HEALTHCHECK --interval=2s CMD [ "/healthcheck.sh"]
CMD [""]