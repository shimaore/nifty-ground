(c) 2012-2015 Stephane Alnet

    path = require 'path'
    {isIPv4,isIPv6} = require 'net'
    packet_server = require './packet_server'
    wireshark_date = require './wireshark_date'
    pkg = require '../package.json'
    debug = (require 'debug') "#{pkg}:trace"

# Host trace server

    default_workdir = path.join process.cwd(), 'pcap'

    class TraceError extends Error

The server filters and formats the trace.

    module.exports = (doc) ->

      debug "start", doc

Stubbornly refuse to print out all packets.

      unless doc.use_xref or doc.to_user? or doc.from_user? or doc.call_id? or doc.ip?
        throw new TraceError 'Either one of `to_user`, `from_user`, `call_id`, or `ip` is a required parameter.'

# Generate a merged capture file

ngrep is used to pre-filter packets

      ngrep_filter = []
      ngrep_filter.push "xref=#{doc.reference}" if doc.use_xref
      ngrep_filter.push '([Tt][Oo]|t)'+     ':[^\r\n]*' + doc.to_user   if doc.to_user?
      ngrep_filter.push '([Ff][Rr][Oo][Mm]|f)'+   ':[^\r\n]*' + doc.from_user if doc.from_user?
      ngrep_filter.push '([Cc][Aa][Ll][Ll]-[Ii][Dd]|i)'+':[^\r\n]*' + doc.call_id   if doc.call_id?
      ngrep_filter = ngrep_filter.join '|'

# Select the proper packets
`tshark` does the final packet selection.
In JSON mode it is also used to output the requested fields.

      tshark_filter = []
      if doc.days_ago?

Wireshark's format: Nov 12, 1999 08:55:44.123

        one_day = 86400*1000
        d = new Date()
        d.setHours(0); d.setMinutes(0); d.setSeconds(0)
        time = d.getTime() - one_day*doc.days_ago
        today    = wireshark_date new Date time
        tomorrow = wireshark_date new Date time+one_day
        tshark_filter.push """
          frame.time >= "#{today}" && frame.time < "#{tomorrow}"
        """

      if doc.ip?
        if isIPv4 doc.ip
          tshark_filter.push """
            (ip.addr == #{doc.ip})
          """
        else if isIPv6 doc.ip
          tshark_filter.push """
            (ipv6.addr == #{doc.ip})
          """

      if tshark_filter.length > 0
        tshark_filter = tshark_filter.join ' && '
      else
        tshark_filter = 'ip'

      options =
        interface: doc.interface
        trace_dir: default_workdir
        # find_filter is left empty
        ngrep_filter: ngrep_filter
        tshark_filter: tshark_filter

      if doc.reference?
        options.pcap = path.join options.trace_dir, ".tmp.cap2.#{doc.reference}"

      [ packet_server(options), options.pcap ]
