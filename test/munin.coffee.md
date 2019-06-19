    (require 'chai').should()

    req = require 'superagent'
    describe 'Munin', ->
      munin = require '../src/munin'

      app = null
      before ->
        process.env.DATA_DIR = 'does not exist'
        app = munin
          web:
            host: '127.0.0.1'
            port: 3939

      after ->
        delete process.env.DATA_DIR
        app.server.close()

      it 'should autoconf', ->
        res = await req.get 'http://127.0.0.1:3939/autoconf'
        res.should.have.property 'ok', true
        res.should.have.property 'text', 'yes\n'

      it 'should conf', ->
        res = await req.get 'http://127.0.0.1:3939/config'
        res.should.have.property 'ok', true
        res.text.should.match /^multigraph dumpcap_reasons_abs/

      it 'should fallback nicely', ->
        res = await req.get 'http://127.0.0.1:3939/'
        res.should.have.property 'ok', true
        res.should.have.property 'text', ''

    describe 'Munin with dir', ->
      munin = require '../src/munin'
      app = null

      before ->
        await fs.mkdir 'data1'
        process.env.DATA_DIR = 'data1'
        app = munin
          web:
            host: '127.0.0.1'
            port: 3940

      after ->
        app.server.close()
        delete process.env.DATA_DIR
        await fs.rmdir 'data1'

      it 'should handle empty dir', ->
        res = await req.get 'http://127.0.0.1:3940/'
        res.should.have.property 'ok', true
        res.text.should.match /^multigraph dumpcap_reasons_abs\ndumpcap_reasons_abs_200.value 0/

    describe 'Munin with file', ->
      munin = require '../src/munin'
      app = null

      before ->
        pcap = Buffer.from '''
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
        pcap_gz = Buffer.from '''
        H4sICHUEM1cAA2Zvby5wY2FwALtyeNNCJgYWBgRgYWAEknaP20MLjJgZQoFsEJ7wLcjt1LWEnDT9
        rhMcDK4MDO7BJx0YHARF/Q6sYH3KxcjIuPmx8BEGY/PwYM8AfSM9AwUTA3OF0LzE0pKM/KLMqtQU
        Lufg1EIrBWNDIzMFT78wzxBXLpAlkebMDIVAC0AYYjzEKqAlBxiSp15lYLBnFC4DWQCyiJn53AWQ
        I2EOsBcUo8QBXkAHPFPkYAgAGhmAzZdO4VwgXwoJwSzZehhoiR77Q4QlFgohmbmp+aUlCPMVkM0X
        UOdgyAGanYPNg3EzloE8KLAKyYOnoR4E220vKEym3YFAu2/mceLxW2w5yG/cS2Hm31ADmf8sE7f5
        hkbGxsjmH+vmxOO32Wogv/FpYfMbyG57QR4y7Y4F2l0Vw8OgDzRNH5vfFJO2gfzG1g4zvyceaD5v
        lr9Hak5OPkg7XyIPgzdQqzc2p9suWA5yOscpJKevgjodbLS9IDt2o0uBRs9L52CIBCqOxOYy7xRX
        kMtYzsG0n1MFajfn9YL53MzARMG1Irm0OFUhNxXqd3MjC0MIhiddkEW3czgYSoGWlGLzQ/qqVJAf
        /j1E8sMVqB/AjrAXZKXUEQDIRiq9PgQAAA==
        ''', 'base64'
        await fs.mkdir 'data2'
        await fs.writeFile 'data2/eth1_00832_20150101120000.pcap', pcap
        await fs.writeFile 'data2/eth1_00833_20150101120010.pcap.gz', pcap_gz
        process.env.DATA_DIR = 'data2'
        app = munin
          web:
            host: '127.0.0.1'
            port: 3941
            timespan: new Date() - new Date '2015-01-01'

      after ->
        app.server.close()
        delete process.env.DATA_DIR
        await fs.unlink 'data2/eth1_00832_20150101120000.pcap'
        await fs.unlink 'data2/eth1_00833_20150101120010.pcap.gz'
        await fs.rmdir 'data2'

      it 'should read pcap file', ->
        res = await req.get 'http://127.0.0.1:3941/'
        res.should.have.property 'ok', true
        res.text.should.match /^multigraph dumpcap_reasons_abs\ndumpcap_reasons_abs_200.value 0[^]*dumpcap_reasons_abs_407.value 4\n/

    fs = (require 'fs').promises
