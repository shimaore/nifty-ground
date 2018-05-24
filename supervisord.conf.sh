#!/bin/sh

default_filesize=10000
default_ringsize=50
default_filter='udp portrange 5060-5299 or udp portrange 15060-15299 or icmp or tcp portrange 5060-5299 or tcp portrange 15060-15299'

filesize="${FILESIZE:-${default_filesize}}"
ringsize="${RINGSIZE:-${default_ringsize}}"
filter="${FILTER:-${default_filter}}"

cat <<'CONF' >supervisord.conf
[supervisord]
nodaemon=true
logfile=/data/supervisord.log
loglevel=info

[inet_http_server]
port=127.0.0.1:2510

[rpcinterface:supervisor]
supervisor.rpcinterface_factory = supervisor.rpcinterface:make_main_rpcinterface

[program:server]
command=/usr/bin/nice node %(here)s/src/server.js
priority=40
autorestart=true
stdout_logfile=/data/server.log
stderr_logfile=/data/server.error

[program:periodic]
command=/usr/bin/nice node %(here)s/src/periodic.js
priority=60
autorestart=true
stdout_logfile=/data/periodic.log
stderr_logfile=/data/periodic.error

[program:munin]
command=/usr/bin/nice node %(here)s/src/munin.js
priority=60
autorestart=true
stdout_logfile=/data/munin.log
stderr_logfile=/data/munin.error

CONF

for intf in ${INTERFACES}; do
  cat <<CONF >>supervisord.conf
[program:dumpcap-${intf}]
command=/usr/bin/dumpcap -p -q -i ${intf} -b filesize:${filesize} -b files:${ringsize} -P -w /data/${intf}.pcap -f '${filter}' -s 65535
priority=20
autorestart=true
stdout_logfile=/data/${intf}.log
stderr_logfile=/data/${intf}.error

CONF
done

exec /usr/bin/supervisord -n
