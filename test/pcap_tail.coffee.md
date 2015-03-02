    chai = require 'chai'
    chai.should()
    chai.use require 'chai-as-promised'

    fs = require 'fs'

    describe 'pcap_tail', ->

      pcap_tail = require '../src/pcap_tail'

      it 'should parse a valid, empty pcap', ->
        fstream = fs.createReadStream 'test/empty.pcap'
        regex = null
        max_length = 10
        stash = []
        uut = pcap_tail.tail fstream, regex, max_length, stash
        uut.should.be.fulfilled
        uut.should.eventually.have.length 0
        uut.should.eventually.have.property 'globalHeader'

      it 'should skip an invalid pcap', ->
        fstream = fs.createReadStream 'test/invalid.pcap'
        regex = null
        max_length = 10
        stash = []
        uut = pcap_tail.tail fstream, regex, max_length, stash
        uut.should.be.fulfilled
        uut.should.eventually.not.have.property 'globalHeader'
