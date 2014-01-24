
Module = require 'module'
path = require 'path'

# Need to look at the function "exports.eval" 
# in "coffee-script/src/coffee-script.coffee"

module.exports = (request) ->
  m = new Module
  start = request.substring 0, 2
  if start isnt './' and start isnt '..'
    m.paths = Module._nodeModulePaths path.resolve '.'
    absrequest = Module._findPath request, m.paths
    unless absrequest
      err = new Error "Cannot find module '#{request}'"
      err.code = 'MODULE_NOT_FOUND'
      throw err
  else
    absrequest = path.resolve '.'
  # m.require absrequest
  try
    m.require absrequest
  catch e
    if e instanceof SyntaxError and e.location
      console.log '--'
      location = path.relative process.cwd(), absrequest
      throw new Error "#{location}:#{e.location.first_line}:#{e.location.first_column} #{e.message}"
    else throw e
