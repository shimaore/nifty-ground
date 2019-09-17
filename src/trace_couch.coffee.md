Concept: the response is stored as a CouchDB record
with the original request as main doc
plus the JSON content as `packets`
plus the PCAP content as attachment `packets.pcap`

This allows for storage of large responses (a potential issue with AMQP).
Also this allows to directly access the raw PCAP output without sending
the request a second time.

    assert = require 'assert'
    CouchDB = require 'most-couchdb'

    json_gather = require './json_gather'
    trace = require './trace'
    qs = require 'querystring'
    {createReadStream,promises:fs} = require 'fs'
    debug = (require 'tangible') "nifty-ground:trace_couch"
    http = require 'http'
    https = require 'https'

    module.exports = (doc) ->
      try
        await handle doc
      catch error
        doc.error = error
      doc

    handle = (doc) ->
      debug "start", doc
      assert doc.reference?, 'The `reference` parameter is required'

      uri = doc.upload_uri ? process.env.UPLOAD
      assert uri?, 'Either the `upload_uri` parameter or the UPLOAD environment variable is required.'

      dest = new CouchDB uri
      [self,pcap] = trace doc

      doc.type = 'trace'
      doc.host = process.env.HOSTNAME
      doc._id = [doc.type, doc.reference, doc.host].join ':'

      packets = await json_gather self

      debug "Trace #{doc.reference} completed, savings #{packets.length} packets."

      doc.packets = packets
      {rev} = await dest.put doc
      doc._rev = rev
      doc.state = 'trace_completed'

      debug "Trace #{doc.reference} completed, uploading #{pcap}"

We cannot use CouchDB's attachment methods because they would require to store the object in memory in a Buffer.

      stream = createReadStream pcap
      stream.on 'error', (error) -> debug.error "source #{pcap}", error

      uri = new URL "#{qs.escape doc._id}/packets.pcap?rev=#{qs.escape rev}", dest.uri+'/'
      agent = switch uri.protocol
        when 'http:'
          http
        when 'https:'
          https

      req = agent.request uri,
        method: 'PUT'
        headers:
          'Content-Type': 'application/vnd.tcpdump.pcap'
          'Accept': 'application/json'

      req.on 'socket', -> debug "put #{uri} from #{pcap}: socket"
      req.on 'error', (error) -> debug.error "put #{uri} from #{pcap}", error
      req.on 'close', ->
        debug "Done saving #{pcap} to #{uri}"
        try
          await fs.unlink pcap
        catch error
          debug.dev "#{error} while unlinking #{pcap}"
        return

      debug "Going to save #{pcap} to #{uri}"
      output = stream.pipe req
      output.on 'error', (error) -> debug.error "output #{pcap} into #{uri}", error
      debug "Piping #{pcap} to #{uri}"
      doc
