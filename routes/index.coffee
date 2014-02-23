r = require 'rethinkdb'

connection = null
r.connect
  host: process.env.RETHINKDB_HOST
  port: process.env.RETHINKDB_PORT
  authKey: process.env.RETHINKDB_AUTH
  (err, conn) ->
    throw err  if err
    connection = conn

reminderQuery = (table, thoroughfare, postalCode, reminderType, streetAddress) ->
  addr = parseInt streetAddress
  r.table table
    .getAll thoroughfare, index: 'thoroughfare'
    .filter r.row('postalCode').eq postalCode
    .filter r.row('reminderType').eq reminderType
    .filter r.row('subThoroughfareRangeStart').le addr
    .filter r.row('subThoroughfareRangeEnd').ge addr

authorQuery = (table, author) ->
  r.table table
    .getAll author, index: 'author'

unionQuery = (table, thoroughfare, postalCode, reminderType, streetAddress, author) ->
  start = reminderQuery table, thoroughfare, postalCode, reminderType, streetAddress
  start.union authorQuery table, author


# Routes
module.exports =
  index: (req, res) ->
    res.send 'You are Here :)<br /><br />- There'
    return

  home: (req, res) ->
    query = reminderQuery 'reminders', req.params.streetName, req.params.zip, 'home', req.params.streetAddress
    if req.query.author?
      query = unionQuery 'reminders', req.params.streetName, req.params.zip, 'home', req.params.streetAddress, req.query.author
    query.run connection, (err, cursor) ->
      throw err  if err
      cursor.toArray (err, result) ->
        throw err  if err
        res.json result
    return

  car: (req, res) ->
    query = reminderQuery 'reminders', req.params.streetName, req.params.zip, 'car', req.params.streetAddress
    if req.query.author?
      query = unionQuery 'reminders', req.params.streetName, req.params.zip, 'car', req.params.streetAddress, req.query.author
    query.run connection, (err, cursor) ->
      throw err  if err
      cursor.toArray (err, result) ->
        throw err  if err
        res.json result
    return

  general: (req, res) ->
    r.table 'reminders'
      .hasFields 'locality'
      .filter r.row('reminderType').eq 'home'
      .run connection, (err, cursor) ->
        throw err  if err
        cursor.toArray (err, result) ->
          throw err  if err
          res.json result
    return

  putReminder: (req, res) ->
    if req.body.author
      r.table 'reminders'
        .insert req.body
        .run connection, (err, result) ->
          throw err  if err
          res.json JSON.stringify(result).uuid
      return
    else
      res.send 400, 'no author'
      return
