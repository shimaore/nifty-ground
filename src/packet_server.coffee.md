(c) 2012-2015 Stephane Alnet

    {spawn} = require('child_process')
    {createReadStream,createWriteStream,promises:fs} = require 'fs'
    path = require 'path'
    zlib = require 'zlib'
    byline = require 'byline'
    {EventEmitter} = require 'events'
    pcap_tail = require './pcap_tail'
    debug = (require 'tangible') "nifty-ground:packet_server"

    minutes = 60*1000 # milliseconds

FIXME Generalize: this is copied from (but really, should be exported by) `huge-play/middleware/*/setup.coffee.md`.

    XRef = /xref[=:]([\w-]+)/

# Fields returned in the "JSON" response.
An additional field "intf" indicates on which interface
the packet was captured.

    trace_field_names = [
      "_ws.col.Time"
      "ip.version"
      "ip.dsfield.dscp"
      "ip.src"
      "ip.dst"
      "ip.proto"
      "udp.srcport"
      "udp.dstport"
      "tcp.srcport"
      "tcp.dstport"
      "sip.Call-ID"
      "sip.Request-Line"
      "sip.Method"
      "sip.r-uri"
      "sip.r-uri.user"
      "sip.r-uri.host"
      "sip.r-uri.port"
      "sip.Status-Line"
      "sip.Status-Code"
      "sip.to.user"
      "sip.from.user"
      "sip.From"
      "sip.from.param"
      "sip.To"
      "sip.to.param"
      "sip.contact.uri"
      "sip.contact.param"
      "sip.User-Agent"
    ]

    tshark_fields = []
    for f in trace_field_names
      tshark_fields.push '-e'
      tshark_fields.push f

    tshark_line_parser = (t) ->
      return if not t?
      t = t.toString 'utf8' # ascii?
      t.trimRight()
      values = t.split /\t/
      result = {}
      for value, i in values
        do (value,i) ->
          return unless value? and value isnt ''
          value.replace /\\"/g, '"' # tshark escapes " into \"
          result[trace_field_names[i]] = value
      return result

Options are:
- interface
- trace_dir
- find_since
- ngrep_filter
- tshark_filter
- pcap          if provided, a PCAP filename

Returned object is an EventEmitter;
it will trigger three event types:
- .on 'data', (data) ->
- .on 'end', () ->
- .on 'close', () ->

    module.exports = (options) ->

      debug "start", options

      trace_dir = options.trace_dir

      self = new EventEmitter

      self.end = ->
        was = self._ended
        self._ended = true
        if not was
          self.emit 'end'
        return

      self.close = ->
        self.end()
        was = self._closed
        self._closed = true
        if not was
          self.emit 'close'
        return

      self.pipe = (s) ->
        if self._ended or self._closed
          debug 'pipe: self already ended or closed'
        if self._pipe
          debug 'pipe: self already piped'
        self._pipe = s
        self.emit 'pipe', s
        return

      run = (intf) ->

        ## Select the proper packets
        tshark_command = [
          'tshark', '-r', fh, '-Y', options.tshark_filter, '-nltud', '-o', 'gui.column.format:Time,%Yut', '-T', 'fields', tshark_fields...
        ]
        if options.pcap?
          tshark_command = [
            tshark_command..., '-P', '-w', options.pcap
          ]

        # stream is tshark.stdout
        tshark_pipe = (stream) ->
          debug "tshark_pipe"
          stream.on 'error', (error) -> console.error 'tshark_pipe', error
          linestream = byline stream
          linestream.on 'data', (line) ->
            data = tshark_line_parser line
            data.intf = intf

Locate xref

            switch
              when m = data['sip.r-uri']?.match XRef
                data.xref = m[1]
              when m = data['sip.from.param']?.match XRef
                data.xref = m[1]
              when m = data['sip.to.param']?.match XRef
                data.xref = m[1]
              when m = data['sip.contact.param']?.match XRef
                data.xref = m[1]

            self.emit 'data', data
          linestream.on 'end', ->
            self.end()
          linestream.on 'error', ->
            console.error "tshark_pipe: linestream error", error
            seld.end()
          return

        # Wait for the pcap_command to terminate.

        run_tshark = ->
          debug "spawn nice #{tshark_command}."
          tshark = spawn 'nice', tshark_command,
            stdio: ['ignore','pipe','ignore']

          tshark_kill = ->
            debug "tshark_kill"
            tshark.kill()

          tshark_kill_timer = setTimeout tshark_kill, 10*minutes

          tshark.on 'exit', (code) ->
            debug "On exit", code:code, tshark_command:tshark_command
            clearTimeout tshark_kill_timer
            # Remove the temporary (pcap) file, it's not needed anymore.
            debug "unlink #{fh}"
            try
              await fs.unlink fh
            catch error
              debug "unlink #{fh}: #{error}"
            # The response is complete
            self.close()

          tshark_pipe tshark.stdout
          return

        debug "run", intf

We _have_ to use a file because tshark cannot read from a pipe/fifo/stdin.
(And we need tshark for its filtering and field selection features.)

        fh = "#{trace_dir}/.tmp.cap1.#{Math.random()}"

# Generate a merged capture file

This function tests whether a file is an acceptable input PCAP file name.

        is_acceptable = (name,stats) ->
          return no unless name.match /^[a-z].+\.pcap/
          if intf?
            return no unless name[0...intf.length] is intf
          return no unless stats.isFile() and stats.size > 80
          file_time = stats.mtime.getTime()
          if options.find_since?
            return no unless options.find_since < file_time
          yes

        debug "readdir #{trace_dir}"

        try
          files = []
          for name in await fs.readdir trace_dir
            await do (name) ->
              full_name = path.join trace_dir, name
              debug "stat #{full_name}"
              stats = await fs.stat full_name
              if is_acceptable name, stats
                files.push name:full_name, time:stats.mtime.getTime()
              return

The idea is that we produce _some_ input even if we can't read all the files.

          files.sort (a,b) -> a.time - b.time

`files` now contains a sorted list of *pcap* files.
We build a stash using the last 500 packets matching `ngrep_filter`.

          stash = []

          for file in files
            await do (file_name = file.name) ->

We shouldn't just crash if createReadStream, zlib, or pcap-parser fail.

              try
                debug "parsing #{file_name}"
                input = createReadStream file_name
                input.on 'error', (error) -> console.error 'input', file_name, error
                if file_name.match /gz$/
                  dec = zlib.createGunzip()
                  dec.on 'error', (error) -> console.error 'gunzip', file_name, error
                  input = input.pipe dec
                  input.on 'error', (error) -> console.error 'gunzip input', file_name, error
                await pcap_tail.tail input, options.ngrep_filter, options.ngrep_limit ? 500, stash

              catch error
                debug "#{error} while parsing #{file_name}"

          debug "Going to write #{stash.length} packets to #{fh}."
          await pcap_tail.write createWriteStream(fh), stash
          run_tshark()

        catch error
          debug "#{error} while processing #{trace_dir}"
          null

      run options.interface

      return self
