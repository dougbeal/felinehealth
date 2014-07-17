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

codeToToken = (auth, code, callback) ->
  console.log "auth code #{code} to tokens." if exports.trace
  auth.getToken code, (error, tokens) ->
    console.log "auth tokens #{util.inspect tokens}." if exports.trace
    auth.credentials = tokens
    callback error, auth

exports.setupTokens = (callback, privateDir) ->
  console.log 'setupTokens' if exports.trace
  async.waterfall [
    readSecretFile = (callback) ->
      fs.readFile path.join(privateDir, secretFileName), 'utf8', (error, data) ->
        if error
          console.log "error reading file: %s", error if exports.trace
          callback error
        else
          secret = JSON.parse data
          fs.readFile path.join(privateDir, authCacheFileName), 'utf8', (error, authCacheData) ->
            authCache = null
            if error
              console.log "error reading auth cache: %s.", error if exports.trace
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
            data = JSON.stringify auth.credentials
            console.log "caching credentials #{authCacheFile} #{data}." if exports.trace
            fs.writeFile authCacheFile, data, (error) ->
                console.log "cached credentials." if exports.trace
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
      callback error, project, auth, client, body

exports.updateFile = (project, auth, client, body, callback) ->
  console.dir body
  file = null
  for file in body.files
    if file.name == 'test'
      break
  projectId = project.id
  fileId = file.id
  console.log "#{file.name} #{file.type} filedid"+
  " #{fileId} projectid #{projectId} " if exports.trace
  file.source = '// updated\n' + file.source
  client.drive.files
  .update fileId: projectId
  .withMedia 'application/json',
    JSON.stringify "files": [file]
  .withAuthClient auth
  .execute callback

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
