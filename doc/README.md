Actual Munin-node plugin
========================

For example `/etc/munin/plugins/dumpcap_reasons`:

    #!/bin/bash
    curl -s ${URL:-http://127.0.0.1:3939}/$1

Set `env.URL` in the plugins' configuration if using a port (or host) different from the defaults:

    [dumpcap_reasons]
    env.URL http://127.0.0.1:4242

Testing with munin-node once installed
======================================

You need to announce the `multigraph` capability in order for 'munin-node' to report the graph.

    echo -n -e 'cap multigraph\nlist\nfetch dumpcap_reasons\nquit\n' | nc localhost 4949

example.pcap
============

The `example.pcap` file was generated using

    echo -n -e 'Hello' | nc -u 10.1.1.1 5060
    echo -n -e 'SIP/2.0 604 Excuse me\nCSeq: 72817281726 INVITE\n' | nc -u 10.1.1.1 5060
    # etc.

and capturing with

    dumpcap -w example.pcap -P -f 'host 10.1.1.1'

then exporting `base64 < example.pcap` into `test/munin.coffee.md`.
