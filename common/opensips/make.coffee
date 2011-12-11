#!/usr/bin/env coffee
# clean.js -- merge OpenSIPS configuration fragments
# Copyright (C) 2009,2011  Stephane Alnet
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

fs = require 'fs'
path = require 'path'

### clean_cfg

  Rename route statements and prune unavailable ones.
  Process macros.

###

macros_cfg = (t,params) ->

  macros = {}

  # Macro pre-processing
  t = t.replace ///
    \b macro \s+ (\w+) \b
    ([\s\S]*?)
    \b end \s+ macro \s+ \1 \b
    ///g, (str,$1,$2) ->
    macros[$1] = $2
    return ''

  # Macros may contain params, so substitute them first.
  t = t.replace /// \$ \{ (\w+) \} ///g, (str,$1) -> macros[$1] ? str

  # One more time (macros within macros)
  t = t.replace /// \$ \{ (\w+) \} ///g, (str,$1) -> macros[$1] ? str

  # Evaluate parameters after macro substitution
  t = t.replace /// \b define \s+ (\w+) \b ///g, (str,$1) ->
    params[$1] = 1
    return ''
  t = t.replace /// \b undef \s+ (\w+) \b ///g, (str,$1) ->
    params[$1] = 0
    return ''

  # Since we don't use a real (LR) parser, these are sorted by match order.
  t = t.replace ///
    \b if \s+ not \s+ (\w+) \b
    ([\s\S]*?)
    \b end \s+ if \s+ not \s+ \1 \b
    ///g, (str,$1,$2) -> if not params[$1] then $2 else ''
  t = t.replace ///
    \b if \s+ (\w+) \s+ is \s+ not \s+ (\w+) \b
    ([\s\S]*?)
    \b end \s+ if \s+ \1 \s+ is \s+ not \s+ \2 \b
    ///g, (str,$1,$2,$3) -> if params[$1] isnt $2 then $3 else ''
  t = t.replace ///
    \b if \s+ (\w+)\ s+ is \s+ (\w+) \b
    ([\s\S]*?)
    \b end \s+ if \s+ \1 \s+ is \s+ \2 \b
    ///g, (str,$1,$2,$3) -> if params[$1] is $2 then $3 else ''
  t = t.replace ///
    \b if \s+ (\w+) \b
    ([\s\S]*?)
    \b end \s+ if \s+ \1 \b
    ///g, (str,$1,$2) -> if params[$1] then $2 else ''

  # Substitute parameters
  t = t.replace /// \$ \{ (\w+) \} ///g, (str,$1) ->
    if params[$1]?
      return params[$1]
    else
      console.log "Undefined #{$1}"
      return str

  return t

clean_cfg = (t,params) ->

  t = macros_cfg t, params

  available = {}
  t.replace /// \b route \[ ( [^\]]+ ) \] ///g, (str,$1) ->
    available[$1] = 0

  t = t.replace /// \b route \( ( [^\)]+ ) \) ///g, (str,$1) ->
    if available[$1]?
      available[$1]++
      return str
    else
      console.log "Removing unknown route(#{$1})"
      return ''

  unused = (k for k,v of available when v is 0)
  if unused? and unused.length
      throw "Unused routes (replace with macros): " + unused.sort().join(', ')

  used = (k for k,v of available when v > 0)

  route_count = 0
  route = {}
  route[_] = ++route_count for _ in used.sort()

  console.log "Found #{route_count} routes"

  t = t.replace /\broute\(([^\)]+)\)\s*([;\#\)])/g, (str,$1,$2) -> "route(#{route[$1]}) #{$2}"
  t = t.replace /\broute\[([^\]]+)\]\s*([\{\#])/g, (str,$1,$2)  -> "route[#{route[$1]}] #{$2}"

  t += "\n"

  keys = (k for k of route)
  t += "# route(#{route[_]}) => route(#{_})\n" for _ in keys.sort()

  return t


### compile_cfg

    Build OpenSIPS configuration from fragments.

###

compile_cfg = (base_dir,params) ->

  recipe = params.recipe

  result =
    """
    #
    # Automatically generated configuration file.
    # #{params.comment}
    #

    """

  for extension in ['variables','modules','cfg']
    for building_block in recipe
      file = path.join base_dir, 'fragments', "#{building_block}.#{extension}"
      try
        fragment  = "\n## ---  Start #{file}  --- ##\n\n"
        fragment += fs.readFileSync file
        fragment += "\n## ---  End #{file}  --- ##\n\n"
        result += fragment
  return clean_cfg result, params

###

  configure_opensips
    Subtitute configuration variables in a complete OpenSIPS configuration file
    (such as one generated by compile_cfg).

###

configure_opensips = (params) ->

  # Handle special parameters specially
  escape_listen = (_) -> "listen=#{_}\n"

  params.listen = params.listen.map(escape_listen).join '' if params.listen?

  cfg_text = compile_cfg params.opensips_base_lib, params

  fs.writeFileSync params.runtime_opensips_cfg, cfg_text

params = {}

for _ in process.ARGV.slice 3
  do (_) ->
    data = JSON.parse fs.readFileSync _
    params[k] = data[k] for own k of data

configure_opensips params
