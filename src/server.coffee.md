    pkg = require '../package.json'
    {debug,foot} = (require 'tangible') "#{pkg.name}:server"

    assert = require 'assert'
    assert process.env.SOCKET?, 'The SOCKET environment variale is required.'
    assert process.env.HOSTNAME?, 'The HOSTNAME environment variale is required.'

    trace_couch = require './trace_couch'
    hostname = process.env.HOSTNAME

Request handler
---------------

    main = ->

Wait for a trace request.

      rr = new RedRingAxon cfg.axon ? {}
      rr.receive 'trace:*'
      .filter ({op}) -> op is UPDATE
      .forEach foot (msg) ->

- `_id`: `trace:<reference>`
- `reference`

        rr.notify msg.id, msg.id,
          _id: msg.id
          state: 'trace_started',
          host:hostname

        debug "received trace request #{JSON.stringify msg.doc}"
        error = await trace_couch(msg.doc).catch (error) -> error.toString()

        rr.notify msg.id, msg.id,
          _id: msg.id
          state: 'trace_completed',
          host:hostname
          error: error

      console.log "#{pkg.name} #{pkg.version} ready on #{hostname}"

    do main
