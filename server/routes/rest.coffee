dotize = Meteor.npmRequire 'dotize'

collection = new Mongo.Collection 'data'
collection._ensureIndex
  _key: 1

createKeysObject = (key) ->
  _keys = key.split('/').reduce (prev, curr, index, arr) ->
    base = if index > 0 then "#{prev[index-1]}/" else ''
    prev.push "#{base}#{curr}"
    prev
  , []

  keys = {}
  keys["#{k}"] = true for k in _keys
  keys

Router.route('/api/v1/:key*', {where: 'server'})
  .get ->
    documents = collection.find("_key.#{@params.key}": true).fetch()

    @response.writeHead 200, 'Content-Type': 'application/json'
    @response.end EJSON.stringify documents.map (doc)-> _.omit doc, '_key', '_id'

  .put ->
    document = @request.body
    docCount = collection.find(_key: createKeysObject @params.key).count()
    if docCount
      @response.writeHead 422, 'Content-Type': 'application/json'
      @response.end EJSON.stringify
        error: 'Document already exists.'
    else
      collection.insert _.extend {_key: createKeysObject @params.key}, document

      @response.writeHead 201, 'Content-Type': 'application/json'
      @response.end EJSON.stringify document

  .post ->
    document = @request.body
    dotizedDocument = dotize.convert document

    docCount = collection.find("_key.#{@params.key}": true).count()
    if docCount is 0
      @response.writeHead 404, 'Content-Type': 'application/json'
      @response.end EJSON.stringify error: 'Document does not exist.'
    else if docCount is 1 or @params.query?.multi is 'true'
      collection.update {"_key.#{@params.key}": true}, {$set: dotizedDocument}, multi: true
      @response.writeHead 200, 'Content-Type': 'application/json'
      documents = collection.find("_key.#{@params.key}": true).fetch()
      @response.end EJSON.stringify documents.map (doc)-> _.omit doc, '_key', '_id'
    else
      @response.writeHead 409, 'Content-Type': 'application/json'
      @response.end EJSON.stringify error: 'There are multiple documents matching your query. Please, use ?multi=true to force update of multiple documents.'

  .delete ->
    docCount = collection.find("_key.#{@params.key}": true).count()
    if docCount is 0
      @response.writeHead 404, 'Content-Type': 'application/json'
      @response.end EJSON.stringify error: 'Document does not exist.'
    else if docCount is 1 or @params.query?.multi is 'true'
      num = collection.remove "_key.#{@params.key}": true
      @response.writeHead 200, 'Content-Type': 'application/json'
      @response.end EJSON.stringify deleted: num
    else
      @response.writeHead 409, 'Content-Type': 'application/json'
      @response.end EJSON.stringify error: 'There are multiple documents matching your query. Please, use ?multi=true to force tremoval of multiple documents.'
