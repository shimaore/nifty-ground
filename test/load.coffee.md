    describe 'The modules', ->
      it 'should load', ->
        require '../src/cleanup'
        require '../src/json_gather'
        require '../src/munin'
        require '../src/packet_server'
        require '../src/pcap_tail'
        require '../src/periodic'
        require '../src/server'
        require '../src/trace'
        require '../src/trace_couch'
        require '../src/wireshark_date'
