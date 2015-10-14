#!/bin/bash

default_filesize=10000
default_ringsize=50
default_filter='udp portrange 5060-5299 or udp portrange 15060-15299 or icmp or tcp portrange 5060-5299 or tcp portrange 15060-15299'

filesize="${FILESIZE:-${default_filesize}}"
ringsize="${RINGSIZE:-${default_ringsize}}"
filter="${FILTER:-${default_filter}}"

cat <<'CONF' >supervisord.conf
[supervisord]
nodaemon=true
logfile=%(here)s/log/supervisord.log
pidfile=%(here)s/log/supervisord.pid
loglevel=info

[inet_http_server]
port=127.0.0.1:2510

[rpcinterface:supervisor]
supervisor.rpcinterface_factory = supervisor.rpcinterface:make_main_rpcinterface

[program:server]
command=/usr/bin/nice %(here)s/node_modules/.bin/coffee %(here)s/src/server.coffee.md
priority=40
autorestart=true
redirect_stderr=true
stdout_logfile=%(here)s/log/%(program_name)s.log
stderr_logfile=%(here)s/log/%(program_name)s.log

[program:periodic]
command=/usr/bin/nice %(here)s/node_modules/.bin/coffee %(here)s/src/periodic.coffee.md
priority=60
autorestart=true
redirect_stderr=true
stdout_logfile=%(here)s/log/%(program_name)s.log
stderr_logfile=%(here)s/log/%(program_name)s.log

[program:munin]
command=/usr/bin/nice %(here)s/node_modules/.bin/coffee %(here)s/src/munin.coffee.md
priority=60
autorestart=true
redirect_stderr=true
stdout_logfile=%(here)s/log/%(program_name)s.log
stderr_logfile=%(here)s/log/%(program_name)s.log

CONF

for intf in ${INTERFACES}; do
  cat <<CONF >>supervisord.conf
[program:dumpcap-${intf}]
command=/usr/bin/dumpcap -p -q -i ${intf} -b filesize:${filesize} -b files:${ringsize} -P -w %(here)s/pcap/${intf}.pcap -f '${filter}' -s 65535
priority=20
autorestart=true
redirect_stderr=true
stdout_logfile=%(here)s/log/%(program_name)s.log
stderr_logfile=%(here)s/log/%(program_name)s.log

CONF
done

exec /usr/bin/supervisord -n