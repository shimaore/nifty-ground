(c) 2012-2015 Stephane Alnet

    module.exports = (self) ->

Aggregate the contents received via `data` events into an Array.

      new Promise (resolve,reject) ->
        try
          res = []

          self.on 'data', (data) ->
            res.push data

          self.on 'end', ->

Returns a Promise that resolves into the Array.

            resolve res
        catch error
          reject error
        return
