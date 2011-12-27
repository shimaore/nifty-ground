###
(c) 2010 Stephane Alnet
Released under the Affero GPL3 license or above
###

# Install:
#   coffee -c replicate.coffee
#   couchapp push replcate.js http://127.0.0.1:5984/db

p_fun = (f) -> '('+f+')'

ddoc =
  _id: '_design/replicate'
  filters: {}

module.exports = ddoc

ddoc.validate_doc_update = p_fun (newDoc, oldDoc, userCtx) ->

  user_is = (role) ->
    userCtx.roles?.indexOf(role) >= 0

  if not user_is('provisioning_writer') and not user_is('_admin')
    throw forbidden:"Not authorized to write in this database, roles = #{userCtx.roles?.join(",")}."

# Filter replication towards the user database.
ddoc.filters.user_pull = p_fun (doc, req) ->

  # Only replicate provisioning documents.
  if not doc.type?
    return false

  provisioning_types = ["number","endpoint","location","host","domain"]

  if provisioning_types.indexOf(doc.type) < 0
    return false

  # They must have a valid account.
  if not doc.account?
    return false

  # The user context provided to us by the replication agent.
  ctx = JSON.parse req.query.ctx

  for role in ctx.roles
    do (role) ->
      # We use the "access" filter to know which documents the user might read.
      prefix = role.match(/^access:provisioning:(.*)$/)?[1]
      if prefix?

        # Replicate documents for which the account is a subset of the prefix.
        if doc.account.substr(0,prefix.length) is prefix
          return true

  # Do not otherwise replicate
  return false
