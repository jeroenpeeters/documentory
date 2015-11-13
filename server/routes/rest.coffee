dotize = Meteor.npmRequire 'dotize'
collectionRefs = {}

getCollection = (name) ->
  unless collectionRefs[name]
    collectionRefs[name] = new Mongo.Collection name
    collectionRefs[name]._ensureIndex
      _key: 1
  collectionRefs[name]

createKeysObject = (key) ->
  _keys = key.split('/').reduce (prev, curr, index, arr) ->
    base = if index > 0 then "#{prev[index-1]}/" else ''
    prev.push "#{base}#{curr}"
    prev
  , []
  keys = {}
  keys["#{k}"] = true for k in _keys
  keys

commonErrorHandler = (cb) -> ->
  unless @params.collectionName
    @response.writeHead 400, 'Content-Type': 'application/json'
    @response.end EJSON.stringify error: 'Root key is required.'
  else
    cb?.call @

Router.route('/api/v1/:collectionName/:key*', {where: 'server'})
.get commonErrorHandler ->
  query = if @params.key then "_key.#{@params.key}": true else {}

  if @params.query
    query[name] = value for name, value of @params.query
  documents = getCollection(@params.collectionName).find(query).fetch()

  @response.writeHead 200, 'Content-Type': 'application/json'
  @response.end EJSON.stringify documents.map (doc)-> _.omit doc, '_key', '_id'

.put commonErrorHandler ->
  document = @request.body
  collection = getCollection(@params.collectionName)
  docCount = collection.find(_key: createKeysObject @params.key).count()
  if docCount
    @response.writeHead 422, 'Content-Type': 'application/json'
    @response.end EJSON.stringify
      error: 'Document already exists.'
  else
    collection.insert _.extend {_key: createKeysObject @params.key}, document

    @response.writeHead 201, 'Content-Type': 'application/json'
    @response.end EJSON.stringify document

.post commonErrorHandler ->
  document = @request.body
  dotizedDocument = dotize.convert document

  collection = getCollection(@params.collectionName)
  docCount = collection.find("_key.#{@params.key}": true).count()
  if docCount is 0
    @response.writeHead 404, 'Content-Type': 'application/json'
    @response.end EJSON.stringify error: 'Document does not exist.'
  else if docCount is 1 or @params.query?._multi is 'true'
    collection.update {"_key.#{@params.key}": true}, {$set: dotizedDocument}, multi: true
    @response.writeHead 200, 'Content-Type': 'application/json'
    documents = collection.find("_key.#{@params.key}": true).fetch()
    @response.end EJSON.stringify documents.map (doc)-> _.omit doc, '_key', '_id'
  else
    @response.writeHead 409, 'Content-Type': 'application/json'
    @response.end EJSON.stringify error: 'There are multiple documents matching your query. Please, use ?_multi=true to force update of multiple documents.'

.delete commonErrorHandler ->
  collection = getCollection(@params.collectionName)
  docCount = collection.find("_key.#{@params.key}": true).count()
  if docCount is 0
    @response.writeHead 404, 'Content-Type': 'application/json'
    @response.end EJSON.stringify error: 'Document does not exist.'
  else if docCount is 1 or @params.query?._multi is 'true'
    num = collection.remove "_key.#{@params.key}": true
    @response.writeHead 200, 'Content-Type': 'application/json'
    @response.end EJSON.stringify deleted: num
  else
    @response.writeHead 409, 'Content-Type': 'application/json'
    @response.end EJSON.stringify error: 'There are multiple documents matching your query. Please, use ?_multi=true to force tremoval of multiple documents.'

Router.route '/api/v1',
  where: 'server'
  action: commonErrorHandler()
