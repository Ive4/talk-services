requireDir = require 'require-dir'
path = require 'path'

service =
  register: require './register'
  loadAll: -> requireDir './services'
  load: (name) -> @loadAll()[name]
  static: (str) -> path.join __dirname, '../static', str
  i18n: (dict) -> dict

module.exports = service
