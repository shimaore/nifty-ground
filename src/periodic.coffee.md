    pkg = require '../package.json'
    debug = (require 'debug') "#{pkg.name}:periodic"

Cleanup the trace directory every hour
--------------------------------------

    cleanup = require './cleanup'
    hourly = 60*60*1000

    setInterval ->

FIXME should try to retrieve `new_interfaces`

      try
        cleanup()
      catch error
        debug "Cleanup: #{error}"
    , hourly
