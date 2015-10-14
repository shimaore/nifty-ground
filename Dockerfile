FROM shimaore/debian:2.0.3
MAINTAINER Stéphane Alnet <stephane@shimaore.net>

# Install Node.js using `n`.
RUN \
  apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    make \
  && git clone https://github.com/tj/n.git \
  && cd n \
  && make install \
  && cd .. \
  && apt-get purge -y \
    make \
  && apt-get autoremove -y \
  && apt-get clean \
  && n 4.2.1

ENV NODE_ENV production

# Required to be able to go through the installation of wireshark-common.
ENV DEBIAN_FRONTEND noninteractive
# `build-essential` is currently required because pouchdb depends on leveldown which must be compiled.
RUN apt-get update && apt-get -y --no-install-recommends install \
  build-essential \
  gzip \
  procps \
  supervisor \
  'tshark=1.12.7+g7fc8978-1'

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

CMD ["/opt/nifty-ground/supervisord.conf.sh"]
