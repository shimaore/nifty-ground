# (c) 2012 Stephane Alnet
#
http = require 'http'
spawn = require('child_process').spawn
fs = require 'fs'

## Host trace server

## Fields returned in the "JSON" response.
trace_field_names = [
  "frame.time"
  "ip.version"
  "ip.dsfield.dscp"
  "ip.src"
  "ip.dst"
  "ip.proto"
  "udp.srcport"
  "udp.dstport"
  "sip.Call-ID"
  "sip.Request-Line"
  "sip.Method"
  "sip.r-uri.user"
  "sip.r-uri.host"
  "sip.r-uri.port"
  "sip.Status-Line"
  "sip.Status-Code"
  "sip.to.user"
  "sip.from.user"
  "sip.From"
  "sip.To"
  "sip.contact.addr"
  "sip.User-Agent"
]

fields = ('-e '+f for f in trace_field_names).join ' '

line_parser = (t) ->
  return if not t?
  t.trimRight()
  values = t.split /\t/
  result = {}
  for value, i in values
    do (value,i) ->
      return unless value? and value isnt ''
      value.replace /\\"/g, '"' # tshark escapes " into \"
      result[trace_field_names[i]] = value
  return result

# Convert a Javascript Date object into a string suitable to feeding
# for wireshark.
wireshark_date = (date) ->
  pad = (n) -> if n < 10 then "0#{n}" else ''+n
  [
    ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][date.getMonth()]
    ' '
    date.getDate()
    ', '
    date.getFullYear()
    ' '
    pad date.getHours()
    ':'
    pad date.getMinutes()
    ':'
    pad date.getSeconds()
  ].join ''

test = ->
  assert = require 'assert'
  assert.equal wireshark_date( new Date '2012-05-07 15:06:56' ), 'May 7, 2012 15:06:56'
  assert.equal wireshark_date( new Date '2040-12-27 07:16:08' ), 'Dec 27, 2040 07:16:08'

# The server filters and formats the trace, and starts a one-time
# web server that will output the data.
module.exports = (config,port,doc) ->

  console.dir port:port, doc: doc

  shell = '/bin/sh'

  workdir = config.traces?.workdir ? '/opt/ccnq3/traces' # FIXME default_trace_workdir

  # We _have_ to use a file because tshark cannot read from a pipe/fifo/stdin.
  # (And we need tshark for its filtering and field selection features.)
  fh = "#{workdir}/.tmp.pcap.#{port}"

  ## Generate a merged capture file
  # ngrep is used to pre-filter packets
  ngrep_filter = []
  ngrep_filter.push 'To'+     ':[^\r\n]*' + doc.to_user   if doc.to_user?
  ngrep_filter.push 'From'+   ':[^\r\n]*' + doc.from_user if doc.from_user?
  ngrep_filter.push 'Call-ID'+':[^\r\n]*' + doc.call_id   if doc.call_id?
  ngrep_filter = ngrep_filter.join '|'

  pcap_command = """
    nice find #{workdir} -name '*.pcap' -size +80c -print0 -o -name '*.pcap.gz' -size +80c -print0 | \\
    nice xargs -0 mergecap -w - | \\
    nice ngrep -i -l -q -I - -O '#{fh}' '#{ngrep_filter}' >/dev/null
  """

  ## Select the proper packets
  # tshark does the final packet selection
  # In JSON mode it is also used to output the requested fields.
  tshark_filter = []
  if doc.days_ago?
    # Wireshark's format: Nov 12, 1999 08:55:44.123
    #
    #
    one_day = 86400*1000
    d = new Date()
    d.setHours(0); d.setMinutes(0); d.setSeconds(0)
    time = d.getTime() - one_day*doc.days_ago
    today    = wireshark_date new Date time
    tomorrow = wireshark_date new Date time+one_day
    tshark_filter.push """
      frame.time >= "#{today}" && frame.time < "#{tomorrow}"
    """
  tshark_filter.push """
    (sip.r-uri.user contains "#{doc.to_user}" || sip.to.user contains "#{doc.to_user}")
  """ if doc.to_user?
  tshark_filter.push """
    sip.from.user contains "#{doc.from_user}"
  """ if doc.from_user?
  tshark_filter.push """
    sip.Call-ID == "#{doc.call_id}"
  """ if doc.call_id?
  tshark_filter = tshark_filter.join ' && '

  switch doc.format
    when 'json'
      tshark_command = """
        nice tshark -r "#{fh}" -R '#{tshark_filter}' -nltad -T fields #{fields}
      """

      # Minimalist web server
      server = http.createServer (req,res) ->

        console.dir req:req,res:res,port:port

        # We don't care to check the method, URI, etc. Just send the response.
        res.writeHead 200,
          'Content-Type': 'application/json'

        # Fork the find/mergecap/ngrep pipe.
        pcap = spawn shell

        # Wait for the pcap_command to terminate.
        pcap.on 'exit', (code) ->
          if code isnt 0
            res.end()
            console.dir on:'exit', code:code, pcap_command:pcap_command, port:port
            return

          tshark = spawn shell
          tshark.on 'exit', (code) ->
            console.dir on:'exit', code:code, tshark_command:tshark_command, port:port

          buffer = ''
          first_entry = true

          process_buffer = ->
            d = buffer.split "\n"
            while d.length > 1
              line = d.shift()
              data = line_parser line
              # Make the array properly formatted
              if first_entry
                res.write '['
              else
                res.write ','
              first_entry = false
              # Write the JSON content
              res.write JSON.stringify(data)
            buffer = d[0]

          tshark.stdout.on 'end', ->
            console.dir on:'end', port:port
            # Process any leftover content
            do process_buffer
            # Close the JSON content
            if first_entry
              res.write '[]'
            else
              res.write ']'
            # The response is complete
            res.end()
            # Remove the temporary (pcap) file
            fs.unlink fh
            # Stop the server (single-shot)
            server.close()

          tshark.stdout.on 'data', (data) ->
            # Accumulate data in the buffer
            buffer += data.toString()
            do process_buffer

          # Start the tshark_command
          console.dir start:tshark_command
          tshark.stdin.write tshark_command
          tshark.stdin.end()

        # Start the pcap_command
        console.dir start:pcap_command
        pcap.stdin.write pcap_command
        pcap.stdin.end()

      server.on 'error', (e) -> console.dir error:e
      console.dir server:'listen', port:port
      server.listen port

    when 'pcap'
      tshark_command = """
        nice tshark -r "#{fh}" -R '#{tshark_filter}' -w - | gzip
      """

      # Minimalist web server
      server = http.createServer (req,res) ->

        console.dir req:req,res:res,port:port

        # We don't care to check the method, URI, etc. Just send the response.
        res.writeHead 200,
          'Content-Type': 'binary/application'
          'Content-Disposition': 'attachment; filename="trace.pcap"'

        # Fork the find/mergecap/ngrep pipe.
        pcap = spawn shell

        # Wait for the pcap_command to terminate.
        pcap.on 'exit', (code) ->
          if code isnt 0
            res.end()
            console.dir on:'exit', code:code, pcap_command:pcap_command, port:port
            return

          tshark = spawn shell
          tshark.on 'exit', (code) ->
            console.dir on:'exit', code:code, tshark_command:tshark_command, port:port

          tshark.stdout.on 'end', ->
            console.dir on:'end', port:port
            # The response is complete
            res.end()
            # Remove the temporary (pcap) file
            fs.unlink fh
            # Stop the server (single-shot)
            server.close()

          # Pipe the output of tshark to the client.
          tshark.stdout.pipe(res)

          # Start the tshark_command
          console.dir start:tshark_command
          tshark.stdin.write tshark_command
          tshark.stdin.end()

        # Start the pcap_command
        console.dir start:pcap_command
        pcap.stdin.write pcap_command
        pcap.stdin.end()

      server.on 'error', (e) -> console.log error:e
      console.dir server:'listen', port:port
      server.listen port
