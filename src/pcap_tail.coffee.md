Provides two methods on a 'stash' (Array) of packet descriptions:

    GLOBAL_HEADER_LENGTH = 24
    PACKET_HEADER_LENGTH = 16

    pcapp = require 'pcap-parser'

    wait_for = (emitter,event,timeout) ->
      new Promise (resolve,reject) ->
        expired = setTimeout reject, timeout
        emitter.once event, (value) ->
          clearTimeout expired
          resolve value
          return
        return

    module.exports =

- `tail` will parse a PCAP input stream, match a `regex` on the packet data if provided, and only keep the last `max_lenght` packets.

      tail: (input_stream,regex,max_length,stash) ->

        new Promise (resolve,reject) ->
          try

            if regex? and typeof regex is 'string'
              regex = new RegExp regex, 'm'

            parser = pcapp.parse input_stream

            parser.on 'globalHeader', (o) ->
              stash.globalHeader ?= o

            parser.on 'packet', (packet) ->
              if regex? and not packet.data.toString('ascii').match regex
                return
              stash.push packet
              if stash.length > max_length
                stash.shift()
              return

            parser.on 'end', ->
              resolve stash

            parser.on 'error', (error) ->
              console.error 'parser', error
              reject error

          catch error
            reject error

- `write` will output a PCAP stream from a stash of packets.

      write: (output_stream,stash) ->
        output_stream.on 'error', (error) ->
          console.error 'pcap_tail.write', error

        send = (data) ->
          unless output_stream.write data
            await wait_for output_stream, 'drain', 1000
          return

        write_packet = (packet) ->
          # Packet Header
          b = new Buffer PACKET_HEADER_LENGTH
          b.writeUInt32LE packet.header.timestampSeconds, 0
          b.writeUInt32LE packet.header.timestampMicroseconds, 4
          b.writeUInt32LE packet.header.capturedLength, 8
          b.writeUInt32LE packet.header.originalLength, 12
          await send b
          await sned packet.data
          return

        # Global Header
        b = new Buffer GLOBAL_HEADER_LENGTH
        b.writeUInt32LE 0xa1b2c3d4, 0
        b.writeUInt16LE 2, 4
        b.writeUInt16LE 4, 6
        b.writeUInt32LE stash.globalHeader?.gmtOffset ? 0, 8
        b.writeUInt32LE stash.globalHeader?.timestampAccuracy ? 0, 12
        b.writeUInt32LE stash.globalHeader?.snapshotLength ? 65535, 16
        b.writeUInt32LE stash.globalHeader?.linkLayerType ? 1, 20
        await send b

        for packet in stash
          packet = stash.shift()
          await write_packet packet
        return
