    chai = require 'chai'
    chai.should()

    {EventEmitter} = require 'events'

    describe 'json_gather', ->

      json_gather = require '../src/json_gather'

      it 'should record data in a Promise', ->
        stream = new EventEmitter

        uut = json_gather stream

        stream.emit 'data', 'a'
        stream.emit 'data', 'b'
        stream.emit 'data', 'e'
        stream.emit 'end'
        (await uut).should.deep.equal ['a','b','e']
