FROM shimaore/nodejs
MAINTAINER Stéphane Alnet <stephane@shimaore.net>

# Required to be able to go through the installation of wireshark-common.
ENV DEBIAN_FRONTEND noninteractive
# `build-essential` is currently required because pouchdb depends on leveldown which must be compiled.
RUN apt-get update && apt-get -y --no-install-recommends install \
  build-essential \
  gzip \
  procps \
  supervisor \
  'tshark=1.12.1+g01b65bf-3'

# Dumpcap can be installed in a way that allows members of the "wireshark" system
# group to capture packets. This is recommended over the alternative of running
# Wireshark/Tshark directly as root, because less of the code will run with
# elevated privileges.
ENV DEBIAN_FRONTEND teletype
RUN echo yes | dpkg-reconfigure --terse wireshark-common

RUN useradd -m -G wireshark nifty-ground
COPY . /opt/nifty-ground
WORKDIR /opt/nifty-ground
RUN chown -R nifty-ground .

USER nifty-ground
RUN mkdir -p log pcap
RUN npm install
RUN npm install coffee-script

CMD ['/opt/nifty-ground/supervisord.conf.sh']
