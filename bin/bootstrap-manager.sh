#!/usr/bin/env bash
# (c) 2011 Stephane Alnet
# License: APGL3+

set -e
export LANG=
NAME=ccnq3
SRC=/opt/$NAME/src
DIR=/etc/$NAME
CONF=${DIR}/host.json
USER=$NAME
# Apparently using /etc/couchdb/local.d/ccnq3 does not work.
COUCHDB_CONFIG=/etc/couchdb/local.ini
RABBITMQ_CONFIG=/etc/rabbitmq/rabbitmq.config

if [ ! -d "${SRC}" ]; then
  echo "ERROR: You must install the $NAME package before calling this script."
  exit 1
fi

cd "$SRC"

if [ -e "${CONF}" ]; then
  echo "ERROR: $CONF already exists."
  exit 1
fi

HOSTNAME=`hostname`

# ----------- CouchDB ---------- #

echo "Re-configuring CouchDB on local host ${HOSTNAME}"

# Using 128 or higher does not work.
ADMIN_PASSWORD=`openssl rand 64 -hex`

# Install default config file
/etc/init.d/couchdb stop
# Double-enforce (currently having issues with this).
killall couchdb beam.smp heart || echo OK

CDB_DIR=/var/lib/couchdb/$NAME
mkdir -p $CDB_DIR
chmod 0755 $CDB_DIR
chown couchdb.couchdb $CDB_DIR

tee "${COUCHDB_CONFIG}" <<EOT >/dev/null
[couchdb]
; Avoid issues with databases disappearing when CouchDB upgrades.
database_dir = ${CDB_DIR}
view_index_dir = ${CDB_DIR}

[httpd]
port = 5984
bind_address = ::
WWW-Authenticate = Basic realm="couchdb"

[couch_httpd_auth]
require_valid_user = true

[log]
level = error

[httpd_global_handlers]
_ccnq3 = {couch_httpd_proxy, handle_proxy_req, <<"http://127.0.0.1:35984/_ccnq3">>}

[admins]
admin = ${ADMIN_PASSWORD}

## Enable the following sections to use SSL (on port 6984 by default).
#
#[daemons]
#httpsd = {couch_httpd, start_link, [https]}
#
#[ssl]
#cert_file = /etc/couchdb/cert.pem
#key_file = /etc/couchdb/key.pem
#
EOT
chown couchdb.couchdb "${COUCHDB_CONFIG}"

/etc/init.d/couchdb start

export CDB_URI="http://admin:${ADMIN_PASSWORD}@${HOSTNAME}:5984"

# -------- RabbitMQ ---------- #

# Delete the default `guest` user.
rabbitmqctl delete_user guest

# Add an `admin` user back in
rabbitmqctl add_user admin "${ADMIN_PASSWORD}"

tee "${RABBITMQ_CONFIG}" <<EOT >/dev/null
%% Enable the following section to use SSL.
%
% [
%   {rabbit, [
%     {ssl_listeners, [5671]},
%     {ssl_options, [{certfile,"/etc/rabbitmq/cert.pem"},
%                    {keyfile,"/etc/rabbitmq/key.pem"}]}
%   ]}
% ].
EOT

export AMQP_URI="amqp://admin:${ADMIN_PASSWORD}@${HOSTNAME}"

exec su -s /bin/bash -c "${SRC}/bin/bootstrap.coffee" "${USER}"
