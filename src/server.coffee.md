    pkg = require '../package.json'
    {debug,foot} = (require 'tangible') "#{pkg.name}:server"
    RedRingAxon = require 'red-rings-axon'

    config = require 'ccnq4-config'

    trace_couch = require './trace_couch'

Request handler
---------------

    main = ->

      assert = require 'assert'
      assert process.env.HOSTNAME?, 'The HOSTNAME environment variable is required.'
      hostname = process.env.HOSTNAME

      cfg = config()

Wait for a trace request.

      rr = new RedRingAxon cfg.axon ? {}
      rr.receive 'trace:*'
      .filter ({op}) -> op is UPDATE
      .forEach foot (msg) ->

- `_id`: `trace:<reference>`
- `reference`

        rr.notify msg.id, msg.id,
          state: 'trace_started',
          host:hostname

        debug "received trace request #{JSON.stringify msg.doc}"
        doc = await trace_couch(msg.doc).catch (error) -> error: error.toString()

        if doc.error?
          rr.notify msg.id, msg.id,
            state: 'trace_error',
            host:hostname
            error: doc.error
          return

        rr.notify doc._id, msg.id, doc

      console.log "#{pkg.name} #{pkg.version} ready on #{hostname}"

    module.exports = main
    if module is require.main
      do main
