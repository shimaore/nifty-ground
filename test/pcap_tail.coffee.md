    chai = require 'chai'
    chai.should()

    fs = require 'fs'

    describe 'pcap_tail', ->

      pcap_tail = require '../src/pcap_tail'

      it 'should parse a valid, empty pcap', ->
        fstream = fs.createReadStream 'test/empty.pcap'
        regex = null
        max_length = 10
        stash = []
        uut = pcap_tail.tail fstream, regex, max_length, stash
        v = await uut
        v.should.have.length 0
        v.should.have.property 'globalHeader'

      it 'should skip an invalid pcap', ->
        fstream = fs.createReadStream 'test/invalid.pcap'
        regex = null
        max_length = 10
        stash = []
        uut = pcap_tail.tail fstream, regex, max_length, stash
        v = await uut
        v.should.not.have.property 'globalHeader'
