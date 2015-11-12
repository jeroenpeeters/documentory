dotize = Meteor.npmRequire 'dotize'
collectionRefs = {}


collection = new Mongo.Collection 'data'
collection._ensureIndex
  _key: 1

###
getCollection = (name) ->
  unless collectionRefs[name]
    collectionRefs[name] = new Mongo.Collection name
    collectionRefs[name]._ensureIndex
      _key: 1
  collectionRefs[name]
###

createKeysObject = (key) ->
  _keys = key.split('/').reduce (prev, curr, index, arr) ->
    base = if index > 0 then "#{prev[index-1]}/" else ''
    prev.push "#{base}#{curr}"
    prev
  , []

  keys = {}
  keys["#{k}"] = true for k in _keys
  keys

Meteor.startup ->
  Router.route('/api/v1/:key*', {where: 'server'})
    .get ->
      documents = collection.find("_key.#{@params.key}": true).fetch()

      @response.writeHead 200, 'Content-Type': 'application/json'
      @response.end EJSON.stringify documents#_.omit document, '_key', '_id'

    .put ->
      document = @request.body
      collection.insert _.extend {_key: createKeysObject @params.key}, document

      @response.writeHead 200, 'Content-Type': 'application/json'
      @response.end EJSON.stringify document

    .post ->
      collection = getCollection @params.collection
      document = @request.body
      dotized = dotize.convert document

      x = collection.update {_key: @params.key}, $set: dotized

      @response.writeHead 200, 'Content-Type': 'application/json'

      document = collection.findOne _key: @params.key
      @response.end EJSON.stringify _.omit document, '_key'
