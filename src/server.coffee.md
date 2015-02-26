    assert = require 'assert'
    assert process.env.SOCKET?, 'The SOCKET environment variale is required.'
    assert process.env.HOSTNAME?, 'The HOSTNAME environment variale is required.'

    trace_couch = require './trace_couch'
    cleanup = require './cleanup'
    pkg = require '../package.json'
    hostname = process.env.HOSTNAME
    client = (require 'socket.io-client') process.env.SOCKET
    hourly = 60*60*1000

    do ->

Configure (see the [spicy-action service](https://github.com/shimaore/spicy-action/blob/master/index.coffee.md) for options).

      client.emit 'configure', traces:yes

Wait for a trace request.

      client.on 'trace', (doc) ->
        console.log "#{pkg.name} #{pkg.version} received trace request #{JSON.stringify doc}"
        Promise.resolve()
        .then ->
          trace_couch doc
        .then ->
          client.emit 'trace_completed', host:hostname, in_reply_to:doc
        .catch (error) ->
          client.emit 'trace_error', host:hostname, in_reply_to:doc, error:error.toString()

Cleanup the trace directory every hour.

      setInterval cleanup, hourly

      console.log "#{pkg.name} #{pkg.version} ready on #{hostname}"
