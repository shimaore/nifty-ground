Concept: the response is stored as a CouchDB record
with the original request as main doc
plus the JSON content as `packets`
plus the PCAP content as attachment `packets.pcap`

This allows for storage of large responses (a potential issue with AMQP).
Also this allows to directly access the raw PCAP output without sending
the request a second time.

    assert = require 'assert'
    request = (require 'superagent-as-promised') require 'superagent'
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
      .then ->
        return unless b?.rev?

We cannot use PouchDB's attachment methods because they would require to store the object in memory in a Buffer.

        uri = url.resolve "#{uri}/", "#{qs.escape doc._id}/packets.pcap"
        console.log "Going to save to #{uri}"
        req = request
          .put uri
          .query rev: b.rev
          .type 'application/vnd.tcpdump.pcap'
        fs.createReadStream(pcap).pipe req
        req

Note: currently this will only unlink if the PUT was successful.
FIXME: Retry the PUT once if it failed.

      .then (res) ->
        console.log "Done saving to #{uri}, ok=#{res.ok}, text=#{res.text}"
        fs.unlinkAsync pcap
      .catch (error) ->
        console.dir {error, when: ''}
