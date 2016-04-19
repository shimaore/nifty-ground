    pkg = require '../package.json'
    debug = (require 'debug') "#{pkg.name}:server"

    assert = require 'assert'
    assert process.env.SOCKET?, 'The SOCKET environment variale is required.'
    assert process.env.HOSTNAME?, 'The HOSTNAME environment variale is required.'

    Promise = require 'bluebird'
    trace_couch = require './trace_couch'
    hostname = process.env.HOSTNAME

Request handler
---------------

    main = ->

      client = (require 'socket.io-client') process.env.SOCKET

      client.on 'connect', ->
        debug 'connect'

Configure (see the [spicy-action service](https://github.com/shimaore/spicy-action/blob/master/index.coffee.md) for options).

        client.emit 'configure', traces:yes

      client.on 'disconnect', ->
        debug 'disconnect'
      client.on 'connect_timeout', ->
        debug 'connect_timeout'
      client.on 'reconnect', ->
        debug 'reconnect'
      client.on 'reconnect_attempt', ->
        debug 'reconnect_attempt'
      client.on 'reconnecting', ->
        debug 'reconnecting'
      client.on 'reconnect_error', ->
        debug 'reconnect_error'
      client.on 'reconnect_failed', ->
        debug 'reconnect_failed'

Wait for a trace request.

      client.on 'trace', (doc) ->
        client.emit 'trace_started',
          host:hostname
          in_reply_to:doc
          _in: "trace:#{doc.reference}"
        debug "received trace request #{JSON.stringify doc}"
        Promise.resolve()
        .then ->
          trace_couch doc
        .then ->
          client.emit 'trace_completed',
            host:hostname
            in_reply_to:doc
            _in: "trace:#{doc.reference}"
        .catch (error) ->
          client.emit 'trace_error',
            host:hostname
            in_reply_to:doc
            error:error.toString()
            _in: "trace:#{doc.reference}"

      client.on 'ping', (doc) ->
        client.emit 'pong',
          host:hostname
          in_reply_to:doc
          name:pkg.name
          version:pkg.version

      console.log "#{pkg.name} #{pkg.version} ready on #{hostname}"

    do main
