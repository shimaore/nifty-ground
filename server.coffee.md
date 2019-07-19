    integer = (t) ->
      v = parseInt t
      return null if isNaN v
      v

    seconds = 1000
    minutes = 60*seconds

    default_filesize=10000
    default_ringsize=50
    default_filter='udp portrange 5060-5299 or udp portrange 15060-15299 or icmp or tcp portrange 5060-5299 or tcp portrange 15060-15299'

    filesize = (integer process.env.FILESIZE) ? default_filesize
    ringsize = (integer process.env.RINGSIZE) ? default_ringsize
    filter = process.env.FILTER ? default_filter

    server = require './src/server'
    do server

    periodic = require './src/periodic'
    do periodic

    munin = require './src/munin'
    munin
      web:
        host: process.env.MUNIN_HOST ? '127.0.0.1'
        port: process.env.MUNIN_PORT ? 3939
        timespan: (integer process.env.MUNIN_TIMESPAN) ? 5*minutes

    {spawn} = require 'child_process'
    {join} = require 'path'
    trace_dir = process.env.DATA_DIR ? '/data'

    child = (intf) ->
      tag = "dumpcap-#{intf}"
      console.log 'start', tag
      cmd = '/usr/bin/dumpcap'
      args = [
        '-p'
        '-q'
        '-i', intf
        '-b', "filesize:#{filesize}"
        '-b', "files:#{ringsize}"
        '-P'
        '-w', join trace_dir, "#{intf}.pcap"
        '-f', filter
        '-s', '65535'
      ]
      options =
        argv0: tag
        stdio: ['ignore','inherit','inherit']

      c = spawn cmd,args,options
      c.on 'error', (error) ->
        console.error 'error', tag, error
      c.on 'exit', (code,signal) ->
        console.error 'exit', tag, code, signal
        process.exit 2
      c.on 'close', (code,signal) ->
        console.error 'close', tag, code, signal

    interfaces = process.env.INTERFACES.split /\s+/
    for intf in interfaces when intf isnt ''
      child intf
