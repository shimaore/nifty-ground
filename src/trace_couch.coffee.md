Concept: the response is stored as a CouchDB record
with the original request as main doc
plus the JSON content as `packets`
plus the PCAP content as attachment `packets.pcap`

This allows for storage of large responses (a potential issue with AMQP).
Also this allows to directly access the raw PCAP output without sending
the request a second time.

    assert = require 'assert'
    request = require 'request'
    PouchDB = require 'pouchdb'

    json_gather = require './json_gather'
    trace = require './trace'
    qs = require 'querystring'
    url = require 'url'
    Promise = require 'bluebird'
    fs = Promise.promisifyAll require 'fs'

    module.exports = (doc) ->
      assert doc.reference?, 'The `reference` parameter is required'

      uri = doc.upload_uri ? process.env.UPLOAD
      assert uri?, 'Either the `upload_uri` parameter or the UPLOAD environment variable is required.'

      dest = new PouchDB uri
      [self,pcap] = trace doc

      doc.type = 'trace'
      doc.host = process.env.HOSTNAME
      doc._id = [doc.type, doc.reference, doc.host].join ':'

      json_gather self
      .then (packets) ->
        doc.packets = packets
        dest.put doc
      .then (b) ->

We cannot use PouchDB's attachment methods because they would require to store the object in memory in a Buffer.

        stream = fs.createReadStream pcap
        req = request.put
          baseUrl: uri
          uri: "#{qs.escape doc._id}/packets.pcap"
          qs:
            rev: b.rev
          headers:
            'Content-Type': 'application/vnd.tcpdump.pcap'
            'Accept': 'json'
          timeout: 60000

        req.on 'error', (error) ->
          console.dir {error, when: ''}

Note: currently this will only unlink if the PUT was successful.
FIXME: Retry the PUT once if it failed.

        req.on 'response', (res) ->
          console.log "Done saving to #{uri}, ok=#{res.ok}, text=#{res.text}"
          fs.unlinkAsync pcap
          .catch (error) ->
            console.log "#{error} while unlinking #{pcap}"

        console.log "Going to save #{pcap} to #{uri}"
        stream.pipe req
        console.log "Piping #{pcap} to #{uri}"
        null
