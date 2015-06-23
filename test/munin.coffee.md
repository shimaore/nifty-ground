    req = (require 'superagent-as-promised') require 'superagent'
    describe 'Munin', ->
      munin = require '../src/munin'

      app = null
      before ->
        app = munin
          web:
            host: '127.0.0.1'
            port: 3939

      after ->
        app.server.close()

      it 'should autoconf', ->
        req
        .get 'http://127.0.0.1:3939/autoconf'
        .then (res) ->
          assert res.ok
          assert res.text is 'yes\n'

      it 'should conf', ->
        req
        .get 'http://127.0.0.1:3939/config'
        .then (res) ->
          assert res.ok
          assert res.text.match /^multigraph dumpcap_reasons_abs/

      it 'should fallback nicely', ->
        req
        .get 'http://127.0.0.1:3939/'
        .then (res) ->
          assert res.ok
          assert res.text is ''

    describe 'Munin with dir', ->
      munin = require '../src/munin'
      app = null

      before ->
        fs.mkdirAsync 'pcap'
        app = munin
          web:
            host: '127.0.0.1'
            port: 3939

      after ->
        app.server.close()
        fs.rmdirAsync 'pcap'

      it 'should handle empty dir', ->
        req
        .get 'http://127.0.0.1:3939/'
        .then (res) ->
          assert res.ok
          assert res.text.match /^multigraph dumpcap_reasons_abs\ndumpcap_reasons_abs_200.value 0/

    describe 'Munin with file', ->
      munin = require '../src/munin'
      app = null

      before ->
        pcap = new Buffer '''
        1MOyoQIABAAAAAAAAAAAAAAABAABAAAAPuOHVXAyAwBVAAAAVQAAAJD2UkbK1mBsZi+KyAgARQAA
        R1PJQABAERVOwKgF5QoBAQGz4xPEADM3V1NJUC8yLjAgNDA3IFVuYXV0aG9yaXplZApDU2VxOiAz
        MTI2IElOVklURQo+44dVWTcDAHEAAABxAAAAYGxmL4rIkPZSRsrWCABFwABjldUAAD8BE3YKAQEB
        wKgF5QMDztAAAAAARQAAR1PJQAA/ERZOwKgF5QoBAQGz4xPEADM3V1NJUC8yLjAgNDA3IFVuYXV0
        aG9yaXplZApDU2VxOiAzMTI2IElOVklURQpK44dV5iEIAFAAAABQAAAAkPZSRsrWYGxmL4rICABF
        AABCVwpAAEAREhLAqAXlCgEBAbXDE8QALgfhU0lQLzIuMCA0MDggVGltZW91dApDU2VxOiAzMTIg
        IElOVklURQpK44dVECcIAGwAAABsAAAAYGxmL4rIkPZSRsrWCABFwABemKYAAD8BEKoKAQEBwKgF
        5QMDzssAAAAARQAAQlcKQAA/ERMSwKgF5QoBAQG1wxPEAC4H4VNJUC8yLjAgNDA4IFRpbWVvdXQK
        Q1NlcTogMzEyICBJTlZJVEUKUeOHVdluCQBQAAAAUAAAAJD2UkbK1mBsZi+KyAgARQAAQl13QABA
        EQulwKgF5QoBAQHYJhPEAC7maVNJUC8yLjAgNDA4IFRpbWVvdXQKQ1NlcTogMTIzMyBJTlZJVEUK
        UeOHVcaLCQBsAAAAbAAAAGBsZi+KyJD2UkbK1ggARcAAXpsmAAA/AQ4qCgEBAcCoBeUDA87LAAAA
        AEUAAEJdd0AAPxEMpcCoBeUKAQEB2CYTxAAu5mlTSVAvMi4wIDQwOCBUaW1lb3V0CkNTZXE6IDEy
        MzMgSU5WSVRFCl3jh1V6XAwALwAAAC8AAACQ9lJGytZgbGYvisgIAEUAACFitkAAQBEGh8CoBeUK
        AQEBjF8TxAANak9IZWxsb13jh1UOYQwASwAAAEsAAABgbGYvisiQ9lJGytYIAEXAAD2gpwAAPwEI
        ygoBAQHAqAXlAwPOqgAAAABFAAAhYrZAAD8RB4fAqAXlCgEBAYxfE8QADWpPSGVsbG9144dVnmcI
        AFkAAABZAAAAkPZSRsrWYGxmL4rICABFAABLZEVAAEARBM7AqAXlCgEBAc4lE8QANw1KU0lQLzIu
        MCA2MDQgRXhjdXNlIG1lCkNTZXE6IDcyODE3MjgxNzI2IElOVklURQp144dV22wIAHUAAAB1AAAA
        YGxmL4rIkPZSRsrWCABFwABnqmUAAD8B/uEKAQEBwKgF5QMDztQAAAAARQAAS2RFQAA/EQXOwKgF
        5QoBAQHOJRPEADcNSlNJUC8yLjAgNjA0IEV4Y3VzZSBtZQpDU2VxOiA3MjgxNzI4MTcyNiBJTlZJ
        VEUK
        ''', 'base64'
        fs.mkdirAsync 'pcap'
        .then ->
          fs.writeFileAsync 'pcap/eth1_00832_20150101120000.pcap', pcap

        app = munin
          web:
            host: '127.0.0.1'
            port: 3939
            timespan: 100*366*86400

      after ->
        app.server.close()
        fs.unlinkAsync 'pcap/eth1_00832_20150101120000.pcap'
        .then ->
          fs.rmdirAsync 'pcap'

      it 'should read pcap file', ->
        req
        .get 'http://127.0.0.1:3939/'
        .then (res) ->
          assert res.ok
          assert res.text.match /^multigraph dumpcap_reasons_abs\ndumpcap_reasons_abs_200.value 0[^]*dumpcap_reasons_abs_407.value 2\n/

    assert = require 'assert'
    Promise = require 'bluebird'
    fs = Promise.promisifyAll require 'fs'
