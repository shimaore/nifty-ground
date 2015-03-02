Live Sniffer Traces Management
==============================

Support for access to local traces.

Make sure the Docker image is started with

    --net=host --privileged=true

so that the packet capture may work!

Environment parameters:
* HOSTNAME: required, FQDN of the local host
* SOCKET: required, where to connect with Socket.IO in order to receive commands.
* INTERFACES: required, space-separated list of interfaces to monitor.
* UPLOAD: required, URI of the database where to upload traces
* RINGSIZE: optional, how many 1Mo files to keep.
* FILESIZE: optional, file size if different from 1Mo.
* FILTER: optional, dumpcap capture filter.

Format
------

Since the `pcap-parser` library only supports old (plain) `pcap` format and not the (newer) `pcap-ng` format, we must dump per interface (`dumpcap` will enforce `pcap-ng` format for multiple interfaces captures).
The capture must be done using a 65535 size to avoid issues with mixing files of differing snapshot lengths.
