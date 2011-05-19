# Zappa

fs = require('fs')
config_location = 'kayako_loginshare.config'
kayako_loginshare_config = JSON.parse(fs.readFileSync(config_location, 'utf8'))

def kayako_loginshare_config: kayako_loginshare_config

json_req = require process.cwd()+'/../../../lib/json_req.coffee'

def json_req: json_req

using 'querystring'

post '/loginshare': ->
  base = kayako_loginshare_config.base
  basic_auth = new Buffer [@username,@password].join(':')
  id = "org.couchdb.user:#{@username}"

  q =
    uri: "#{base}/_users/#{querystring.stringify(id)}"
    headers:
      authorization: "Basic #{basic_auth.toString('base64')}"

  json_req.request q, (p) ->
    if p.error? or not p._id
      send """
           <?xml version="1.0" encoding="UTF-8"?>
           <loginshare>
             <result>0</result>
             <message>Invalid Username or Password</message>
           </loginshare>
           """
    else
      send """
           <?xml version="1.0" encoding="UTF-8"?>
           <loginshare>
             <result>1</result>
             <user>
               <usergroup>Registered</usergroup>
               <fullname>#{@first_name} #{@last_name}</fullname>
               <emails>
                 <email>#{@email}</email>
               </emails>
               <phone>#{@phone}</phone>
             </user>
           </loginshare>
           """
