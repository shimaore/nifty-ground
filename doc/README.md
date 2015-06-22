The `example.pcap` file was generated using

    echo -n -e 'Hello' | nc -u 10.1.1.1 5060
    echo -n -e 'SIP/2.0 604 Excuse me\nCSeq: 72817281726 INVITE\n' | nc -u 10.1.1.1 5060
    # etc.

and capturing with

    dumpcap -w example.pcap -P -f 'host 10.1.1.1'

then exporting `base64 < example.pcap` into `test/munin.coffee.md`.
