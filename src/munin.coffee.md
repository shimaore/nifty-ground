Web Services for Munin
======================

    run = (cfg) -> Zappa cfg.web, ->

      @get '/autoconf', ->
        @send 'yes\n'
        return

      @get '/config', ->
        @send config_abs + config_rel
        return

      @get '/', ->

        now = new Date()
        since = new Date now - cfg.web.timespan
        count = {}
        total = 0

        fs.readdirAsync trace_dir
        .map (name)  ->
          new Promise (resolve,reject) ->
            try
              return unless m = name.match /^eth[^_]+_\d+_\d+.pcap(.gz)?$/
              full_name = path.join trace_dir, name
              debug "Going to parse", full_name
              input = fs.createReadStream full_name
              input = input.pipe zlib.createGunzip() if m[1]?
              parser = parse input
              parser.on 'packet', ({header:{timestampSeconds},data}) ->
                time = new Date timestampSeconds*1000
                content = data.toString 'ascii'
                return unless since < time < now

FIXME: This is highly unsatisfactory as it will also match (as the data example shows) ICMP response packets.

                m = content.match /SIP\/2.0 ([2-6]\d\d) [^]*CSeq: \d+ INVITE/i
                return unless m
                count[m[1]] ?= 0
                count[m[1]]++
                total++
              parser.on 'end', ->
                resolve()

            catch error
              reject error

Since each parser opens a file, keep at most 20 of them open at any given time.

        , concurrency: 20
        .then ->
          response_abs = ''
          response_rel = ''
          for entry in colors
            {code} = entry
            value = count[code] ? 0

Response for the 'absolute' graph

            response_abs += """
              #{name}_abs_#{code}.value #{value}

            """

Response for the 'relative' (percent) graph

            rel_value = if total is 0
                0
              else
                (value*100.0/total).toFixed 2

            response_rel += """
              #{name}_#{code}.value #{rel_value}

            """

Build the complete response.

          """
            multigraph #{name}_abs
            #{response_abs}
            multigraph #{name}
            #{response_rel}
          """

        .then (response) =>
          @send response
          return
        .catch (error) =>
          debug "#{error} while processing #{trace_dir}"
          @send ''
          return

Colors
======

    colors = [
      { code:200, color:"00ff0f" }
      { code:203, color:"00ff1f" }
      { code:204, color:"00ff2f" }
      { code:205, color:"00ff3f" }
      { code:206, color:"00ff4f" }
      { code:209, color:"00ff5f" }
      { code:235, color:"00ff6f" }
      { code:236, color:"00ff7f" }
      { code:260, color:"00ff8f" }
      { code:288, color:"00ff9f" }
      { code:302, color:"007f0f" }
      { code:370, color:"007f1f" }
      { code:400, color:"ff1000" }
      { code:403, color:"ff2000" }
      { code:404, color:"ff3000" }
      { code:407, color:"ff4000" }
      { code:408, color:"ff4000" }
      { code:410, color:"ff5000" }
      { code:415, color:"ff6000" }
      { code:450, color:"ff7000" }
      { code:455, color:"ff8000" }
      { code:480, color:"ff9070" }
      { code:481, color:"ffa070" }
      { code:484, color:"ffb000" }
      { code:485, color:"ffc000" }
      { code:486, color:"7f1030" }
      { code:487, color:"7f2070" }
      { code:488, color:"ffd000" }
      { code:491, color:"ffe000" }
      { code:500, color:"0000f0" }
      { code:502, color:"0010f0" }
      { code:503, color:"0020f0" }
      { code:504, color:"0030f0" }
      { code:603, color:"ff10ff" }
      { code:604, color:"ff20ff" }
      { code:606, color:"ff30ff" }
    ]

Munin Configuration
===================

    name = 'dumpcap_reasons'

    config_abs = """
      multigraph #{name}_abs
      graph_title Reasons codes (cps)
      graph_args -l 0
      graph_vlabel reason codes (cps)
      graph_category voice
      #{name}_abs_total.label Total
      #{name}_abs_total.graph no
      #{name}_abs_total.type ABSOLUTE

    """

    config_rel = """
      multigraph #{name}
      graph_title Reasons codes (%)
      graph_args -l 0
      graph_vlabel reason codes (%)
      graph_category voice

    """

    for entry in colors
      {code,color} = entry

      config_abs += """
        #{name}_abs_#{code}.label SIP #{code}
        #{name}_abs_#{code}.info INVITE messages with #{code} final code
        #{name}_abs_#{code}.colour #{color}
        #{name}_abs_#{code}.draw AREASTACK
        #{name}_abs_#{code}.type ABSOLUTE

      """

      config_rel += """
        #{name}_#{code}.label SIP #{code}
        #{name}_#{code}.info Percentage of INVITE messages with #{code} final code
        #{name}_#{code}.colour #{color}
        #{name}_#{code}.draw AREASTACK
        #{name}_#{code}.type GAUGE

      """

Toolbox
=======

    Promise = require 'bluebird'
    {parse} = require 'pcap-parser'
    Zappa = require 'zappajs'
    fs = Promise.promisifyAll require 'fs'
    path = require 'path'
    pkg = require '../package.json'
    debug = (require 'debug') "#{pkg.name}:munin"

    trace_dir = path.join process.cwd(), 'pcap'

    seconds = 1000
    minutes = 60*seconds

Start
=====

    cfg =
      web:
        host: process.env.MUNIN_HOST ? '127.0.0.1'
        port: process.env.MUNIN_PORT ? 3939
        timespan: process.env.MUNIN_TIMESPAN ? 5*minutes

    module.exports = run
    if module is require.main
      run cfg
