FROM node:10-alpine
MAINTAINER Stéphane Alnet <stephane@shimaore.net>

ENV NODE_ENV production

RUN apk --update add \
  gzip \
  procps \
  supervisor \
  su-exec \
  tshark \
  wireshark-common

# Dumpcap can be installed in a way that allows members of the "wireshark" system
# group to capture packets. This is recommended over the alternative of running
# Wireshark/Tshark directly as root, because less of the code will run with
# elevated privileges.

RUN \
  addgroup -S wireshark && \
  adduser -g '' -G wireshark -D nifty-ground && \
  chgrp wireshark /usr/bin/dumpcap && \
  chmod o-x /usr/bin/dumpcap && \
  setcap cap_net_raw,cap_net_admin=eip /usr/bin/dumpcap

COPY . /opt/nifty-ground
WORKDIR /opt/nifty-ground
RUN chown -R nifty-ground .

USER nifty-ground
RUN \
  npm install && \
  npm run build && \
  npm cache -f clean

USER root

RUN mkdir /data && chown nifty-ground /data
VOLUME /data

ENTRYPOINT ["/opt/nifty-ground/docker-entrypoint.sh"]
CMD ["/opt/nifty-ground/supervisord.conf.sh"]
