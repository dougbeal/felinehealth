googleapis = require 'googleapis'


fs = require 'fs'
path = require 'path'
openurl = require 'openurl'
request = require 'request'
async = require 'async'
http = require 'http'
url = require 'url'
util = require 'util'

SCOPE = 'https://www.googleapis.com/auth/drive ' +
  'https://www.googleapis.com/auth/drive.scripts ' +
  'https://www.googleapis.com/auth/drive.file'


secretFileName = 'client_secrets.json'
authCacheFileName = '.auth.json'

#PROJECT_ID = 'MSH9oPCII3Zn2sKbg_G_Uw2UsQYxi2WFG'
#PROJECT_URL = 'https://script.google.com/feeds/download/export?id=' +
#  PROJECT_ID + "&format=json"
#testProjectID = "1idzRPIjiymntvkxgibT6Fz-mLQX7IGG3eVSdz4bSKNku5rN93VP3y7g2"
exports.trace = false
exports.privateDir = "~/.private"

codeToToken = (auth, code, callback) ->
  console.log "auth code #{code} to tokens." if exports.trace
  auth.getToken code, (error, tokens) ->
    console.log "auth tokens #{util.inspect tokens}." if exports.trace
    auth.credentials = tokens
    callback error, auth

refreshToken = (auth, callback) ->
  console.log "refresh token"
  auth.refreshAccessToken (error, credentials) ->
    writeCredentials auth, (fileError, auth) ->
      callback error, auth

writeCredentials = (auth, callback) ->
  data = JSON.stringify auth.credentials
  if exports.trace
    console.log "caching credentials #{authCacheFileName} #{data}."
  dest = path.join exports.privateDir, authCacheFileName
  fs.writeFile dest, data, (fileError) ->
    if fileError
      console.log "error caching credentials #{fileError}."
    else
      console.log "cached credentials." if exports.trace
    callback fileError, auth

exports.setupTokens = (callback) ->
  console.log 'setupTokens' if exports.trace
  async.waterfall [
    readSecretFile = (callback) ->
      source = path.join(exports.privateDir, secretFileName)
      fs.readFile source, 'utf8', (error, data) ->
        if error
          console.log "error reading file: %s", error if exports.trace
          callback error
        else
          secret = JSON.parse data
          source = path.join(exports.privateDir, authCacheFileName)
          fs.readFile source, 'utf8', (error, authCacheData) ->
            authCache = null
            if error
              if exports.trace
                console.log "error reading auth cache: %s.", error
            else
              authCache = JSON.parse authCacheData
            callback null, secret, authCache
    ,
    startAuthorizationListener = (secret, authCache, callback) ->
      console.log "secret: ", util.inspect secret if exports.trace
      console.log "authcache: ", util.inspect authCache if exports.trace
      auth = new googleapis.OAuth2Client secret.installed.client_id,
        secret.installed.client_secret
      if authCache
        auth.credentials = authCache
        callback null, auth
      else
        server = null
        server = http.createServer (request, response) ->
          # google authorization redirect
          uri = url.parse request.url, true
          if uri.pathname == '/favicon.ico'
            console.log "http rejected #{uri.pathname}" if exports.trace
            response.writeHead 404, {"Content-Type": "text/plain"}
            response.write "404 - no favicon\n"
            response.end
            return
          console.log "http path #{uri.pathname}" if exports.trace
          code = uri.query.code
          response.writeHead 200, {"Content-Type": "text/plain"}
          response.write "Erp derp\n"
          response.write code + '\n'
          response.end
          request.connection.end
          request.connection.destroy
          server.close
          codeToToken auth, code, (error, auth) ->
            writeCredentials auth, (fileError, auth) ->
              callback error, auth
        .listen 0, '127.0.0.1', () ->
          address = server.address()
          auth = new googleapis.OAuth2Client secret.installed.client_id,
            secret.installed.client_secret,
            'http://' + address.address + ':' + address.port
          authurl = auth.generateAuthUrl scope: SCOPE
          openurl.open authurl
      ],
      (error, auth) ->
        callback error, auth

exports.setupDrive = (auth, callback) ->
  console.log 'setupDrive - loading google drive api' if exports.trace
  googleapis.discover 'drive', 'v2'
  .execute (error, client) ->
    callback error, auth, client

exports.listProjects = (auth, client, callback) ->
  console.log "listing projects" if exports.trace
  client.drive.files
    .list q: "mimeType='application/vnd.google-apps.script'"
    .withAuthClient auth
    .execute (error, result) ->
      callback error, result, auth, client

exports.selectProject = (projects, auth, client, callback) ->
  console.log 'project titles: ' + if exports.trace
    ("'#{project.title}'" for project in projects)
  console.dir projects[0]
  exportLinks = (project.exportLinks for project in projects)
  links = for type, link of exportLinks[0]
    link
  id = testProjectID
  #id = projects[0].id
  testLink = [ "https://script.google.com/feeds/download/export?id="+
    "#{id}&format=json"]
  callback null, id, testLink, auth, client

#untested
exports.downloadFileMetadata = (id, auth, client, callback) ->
  console.log "loading project file #{id}." if exports.trace
  client.drive.files
  .get fileId:id
  .withAuthClient auth
  .execute (error, meta) ->
    switch error.code
      when 404
        console.log "failed to load file metadata."
        callback error, null, auth, client
        break
      else
        console.log "file #{id} - #{util.inspect meta}"
        callback error, meta, auth, client

exports.loadProjectFile = (id, links, auth, client, callback) ->
  console.log "loading project file #{id}." if exports.trace
  client.drive.files
  .get fileId:id
  .withAuthClient auth
  .execute (error, projectFile) ->
    if error.code == 404
      console.log "failed to load project file." if exports.trace
      error = null
      projectFile = id:id
    callback error, projectFile, links, auth, client

exports.downloadProject = (project, links, auth, client, callback) ->
  console.log 'project export links: ' + links if exports.trace
  request links[0],
    auth:
      bearer: auth.credentials.access_token
    json: true
    ,
    (error, response, body) ->
      console.log "download error #{error}" if error
      console.log "download response #{response.statusCode}" if exports.trace
      switch response.statusCode
        when 401 then refreshToken auth, (error, auth) ->
          exports.downloadProject project, links, auth, client, callback
        else
          callback error, project, auth, client, body

exports.updateFile = (id, data, auth, client, callback) ->
  console.log "id #{id}  #{util.inspect data} " if exports.trace
  client.drive.files
  .update fileId: id
  .withMedia 'application/json', data
  .withAuthClient auth
  .execute (error, result) ->
    console.log "updateFile er #{util.inspect error} re #{util.inspect result}" if exports.trace
    callback error, result

test = ->
  async.waterfall [
    exports.setupTokens
    exports.setupDrive
    exports.listProjects
    ],
    (error, results) ->
      if error
        console.log "error #{error}"
      else
        console.log "done #{util.inspect results}"
