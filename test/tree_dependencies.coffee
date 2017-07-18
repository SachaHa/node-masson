
should = require 'should'
nikita = require 'nikita'
tree = require '../lib/tree'

describe 'tree dependencies', ->

  tmp = '/tmp/masson-test'
  beforeEach (next) ->
    require('module')._cache = {}
    nikita.mkdir destination: tmp, next
  afterEach (next) -> nikita.remove tmp, next

  describe 'default command', ->

    it 'find dependencies without a command', (next) ->
      nikita.file [
        destination: "#{tmp}/module_1.coffee"
        content: """
        module.exports = [
          '#{tmp}/module_2'
          {name: 'middleware 1', handler: (next) -> next()}
          '#{tmp}/module_3'
        ]
        """
      ,
        destination: "#{tmp}/module_2.coffee"
        content: """
        module.exports = [name: 'middleware 2', handler: (next) -> next()]
        """
      ,
        destination: "#{tmp}/module_3.coffee"
        content: """
        module.exports = [name: 'middleware 3', handler: (next) -> next()]
        """
      ], (err) ->
        tree("#{tmp}/module_1").middlewares command: 'install', (err, middlewares) ->
          middlewares.length.should.eql 3
          middlewares[0].should.have.properties name: 'middleware 2'
          middlewares[1].should.have.properties name: 'middleware 1'
          middlewares[2].should.have.properties name: 'middleware 3'
          next()

    it 'find dependencies and filter other commands', (next) ->
      nikita.file [
        destination: "#{tmp}/module_1.coffee"
        content: """
        module.exports = [
          {commands: 'install', modules: '#{tmp}/module_2'}
          {commands: 'start', modules: '#{tmp}/module_3'}
          {name: 'middleware 1', handler: (next) -> next()}
        ]
        """
      ,
        destination: "#{tmp}/module_2.coffee"
        content: """
        module.exports = [name: 'middleware 2', handler: (next) -> next()]
        """
      ,
        destination: "#{tmp}/module_3.coffee"
        content: """
        module.exports = [name: 'middleware 3', handler: (next) -> next()]
        """
      ], (err) ->
        tree("#{tmp}/module_1").middlewares command: 'install', (err, middlewares) ->
          middlewares.length.should.eql 2
          middlewares[0].should.have.properties name: 'middleware 2'
          middlewares[1].should.have.properties name: 'middleware 1'
          next()

    it 'filter commands inside filtered out modules', (next) ->
      # We need to recompute module dependencies after module are filtered out
      # or the ordering may be wrong
      nikita.file [
        destination: "#{tmp}/module_1.coffee"
        content: """
        module.exports = [
          {commands: 'install', modules: '#{tmp}/module_2'}
        ]
        """
      ,
        destination: "#{tmp}/module_2.coffee"
        content: """
        module.exports = [
          { commands: 'start', modules: '#{tmp}/module_2_start'}
          { name: 'middleware 2', modules:[
            '#{tmp}/module_2_install'
            '#{tmp}/module_2_start'
          ] }
        ]
        """
      ,
        destination: "#{tmp}/module_2_install.coffee"
        content: """
        module.exports = [name: 'middleware 3 install', handler: (next) -> next()]
        """
      ,
        destination: "#{tmp}/module_2_start.coffee"
        content: """
        module.exports = [name: 'middleware 3 start', handler: (next) -> next()]
        """
      ], (err) ->
        tree("#{tmp}/module_1").middlewares command: 'install', modules: "#{tmp}/module_1", (err, middlewares) ->
          middlewares[0].should.have.properties name: 'middleware 3 install'
          middlewares[1].should.have.properties name: 'middleware 3 start'
          next()

  describe 'custom command', ->

    it 'find dependencies', (next) ->
      nikita.file [
        destination: "#{tmp}/module_1.coffee"
        content: """
        module.exports = [
          {commands: 'status', modules: '#{tmp}/module_2'}
          {commands: 'status', name: 'middleware 1', handler: (next) -> next()}
          {commands: 'status', modules: '#{tmp}/module_3'}
          {commands: 'status', modules: 'package_1/module_4'}
        ]
        """
      ,
        destination: "#{tmp}/module_2.coffee"
        content: """
        module.exports = [name: 'middleware 2', handler: (next) -> next()]
        """
      ,
        destination: "#{tmp}/module_3.coffee"
        content: """
        module.exports = [name: 'middleware 3', handler: (next) -> next()]
        """
      ,
        destination: "#{tmp}/node_modules/package_1/module_4.coffee"
        content: """
        module.exports = [name: 'middleware 4', handler: (next) -> next()]
        """
      ], (err) ->
        tree("#{tmp}/module_1").middlewares command: 'status', (err, middlewares) ->
          middlewares.length.should.eql 4
          middlewares[0].should.have.properties name: 'middleware 2'
          middlewares[1].should.have.properties name: 'middleware 1'
          middlewares[2].should.have.properties name: 'middleware 3'
          middlewares[3].should.have.properties name: 'middleware 4'
          next()

    it 'find dependencies and filter other commands', (next) ->
      nikita.file [
        destination: "#{tmp}/module_1.coffee"
        content: """
        module.exports = [
          {commands: 'status', modules: '#{tmp}/module_2'}
          {commands: 'start', name: 'middleware 1.1', handler: (next) -> next()}
          {commands: 'status', name: 'middleware 1.2', handler: (next) -> next()}
          {commands: 'start', modules: '#{tmp}/module_3'}
        ]
        """
      ,
        destination: "#{tmp}/module_2.coffee"
        content: """
        module.exports = [name: 'middleware 2', handler: (next) -> next()]
        """
      ,
        destination: "#{tmp}/module_3.coffee"
        content: """
        module.exports = [name: 'middleware 3', handler: (next) -> next()]
        """
      ], (err) ->
        tree("#{tmp}/module_1").middlewares command: 'status', (err, middlewares) ->
          middlewares.length.should.eql 2
          middlewares[0].should.have.properties name: 'middleware 2'
          middlewares[1].should.have.properties name: 'middleware 1.2'
          next()
