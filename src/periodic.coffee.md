    debug = (require 'tangible') "nifty-ground:periodic"

Cleanup the trace directory every hour
--------------------------------------

    cleanup = require './cleanup'
    hourly = 60*60*1000

    main = ->
      setInterval ->

FIXME should try to retrieve `new_interfaces`

        try
          cleanup()
        catch error
          debug.dev "Cleanup: #{error}"
      , hourly

    module.exports = main
    if module is require.main
      do main
