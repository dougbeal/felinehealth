# ** Cakefile Template ** is a Template for a common Cakefile that you may use in a coffeescript nodejs project.
#
# It comes baked in with 5 tasks:
#
# * build - compiles your src directory to your lib directory
# * watch - watches any changes in your src directory and automatically compiles to the lib directory
# * test  - runs mocha test framework, you can edit this task to use your favorite test framework
# * docs  - generates annotated documentation using docco
# * clean - clean generated .js files
files = [
  'build'
  'drivesync.coffee'
  'test/drivesync_test.coffee'
  'library.coffee'
  'test/library_test.coffee'
  ]

copy_files = [
  'sidebar.html'
  'container.js'
  ]

fs = require 'fs'
path = require 'path'
{print} = require 'util'
{spawn, exec} = require 'child_process'
drivesync = require './build/drivesync'
async = require 'async'
util = require 'util'
readline = require 'readline'

try
  which = require('which').sync
catch err
  if process.platform.match(/^win/)?
    console.log 'WARNING: the which module is required for windows\ntry: npm install which'
  which = null

# ANSI Terminal Colors
bold = '\x1b[0;1m'
green = '\x1b[0;32m'
reset = '\x1b[0m'
red = '\x1b[0;31m'

privateDir = path.join __dirname, ".private"
selectionFile = path.join privateDir, "selection.json"
projectFile = path.join privateDir, "project.json"
drivesync.privateDir = privateDir
projectDownloadDir = path.join __dirname, files[0], 'download'
buildDir = path.join __dirname, files[0]

googleType =
  server_js: 'js'

# Cakefile Tasks
#
# ## *docs*
#
# Generate Annotated Documentation
#
# <small>Usage</small>
#
# ```
# cake docs
# ```
task 'docs', 'generate documentation', -> docco()

# ## *build*
#
# Builds Source
#
# <small>Usage</small>
#
# ```
# cake build
# ```
task 'build', 'compile source', (options) ->
  process_options options
  build -> log ":)", green

# ## *watch*
#
# Builds your source whenever it changes
#
# <small>Usage</small>
#
# ```
# cake watch
# ```
task 'watch', 'compile and watch', (options) ->
  process_options options
  watch

task 'watchtest', 'compile, test, and watch', (options) ->
  process_options options
  watch mocha

# ## *test*
#
# Runs your test suite.
#
# <small>Usage</small>
#
# ```
# cake test
# ```
task 'test', 'run tests', (options) ->
  process_options options
  build -> mocha -> log ":)", green

# ## *clean*
#
# Cleans up generated js files
#
# <small>Usage</small>
#
# ```
# cake clean
# ```
task 'clean', 'clean generated files', (options) ->
  process_options options
  clean -> log ";)", green

task 'list', 'list google drive script projects', (options) ->
  process_options options
  list -> log ";)", green

task 'select', 'select a google drive script project', (options) ->
  process_options options
  list (error, projects) ->
    select projects, (error, project) ->
      writeSelection project, (error, project) ->
        log ";)", green

task 'download', 'download selected google drive script project', (options) ->
  process_options options
  readSelection (error, project) ->
    if error
      list (error, projects) ->
        select options, projects, (error, project) ->
          writeSelection project, (error, project) ->
            out "download selected '#{project.title}'" if verbose
            download project, (error, project) ->
              log ";)", green
    else
      out "download previously selected '#{project.title}'" if verbose
      download project, (error, project) ->
        log ";)", green

do_upload = (error, meta) ->
  out "do_upload" if trace
  readProject (error, project) ->
    out "project #{project} error #{error}" if trace
    if error
      out "failed to read project #{error}."
    upload meta, project, (error) ->
      if error
        log ";(", red
      else
        log ";)", green

task 'upload', 'uploads files from bild matching project files', (options) ->
  process_options options
  out "task upload" if trace
  build ->
    readSelection (error, project) ->
      if error
        out "error #{error} during readSelection"
        list (error, projects) ->
          select projects, (error, project) ->
            writeSelection project, do_upload
      else
        out "title '#{project.title}'" if verbose
        do_upload error, project

task 'site', 'Build github Jekyll _site', (options) ->
  process_options options
  site (error) ->
    if error
      log ";(", red
    else
      log ";)", green




# Internal Functions
#
# ## *walk*
#
# **given** string as dir which represents a directory in relation to local directory
# **and** callback as done in the form of (err, results)
# **then** recurse through directory returning an array of files
#
# Examples
#
# ``` coffeescript
# walk 'src', (err, results) -> console.log results
# ```
walk = (dir, done) ->
  results = []
  fs.readdir dir, (err, list) ->
    return done(err, []) if err
    pending = list.length
    return done(null, results) unless pending
    for name in list
      file = "#{dir}/#{name}"
      try
        stat = fs.statSync file
      catch err
        stat = null
      if stat?.isDirectory()
        walk file, (err, res) ->
          results.push name for name in res
          done(null, results) unless --pending
      else
        results.push file
        done(null, results) unless --pending

# ## *log*
#
# **given** string as a message
# **and** string as a color
# **and** optional string as an explanation
# **then** builds a statement and logs to console.
#
log = (message, color, explanation) -> console.log color + message + reset + ' ' + (explanation or '')

# ## *launch*
#
# **given** string as a cmd
# **and** optional array and option flags
# **and** optional callback
# **then** spawn cmd with options
# **and** pipe to process stdout and stderr respectively
# **and** on child process exit emit callback if set and status is 0
launch = (cmd, options=[], callback) ->
  out "launch:#{cmd} #{options}" if trace
  cmd = which(cmd) if which
  app = spawn cmd, options
  app.stdout.pipe(process.stdout)
  app.stderr.pipe(process.stderr)
  app.on 'exit', (status) ->
    if status is 0
      callback()
    else
      process.exit status

launchError = (cmd, options=[], callback) ->
  out "launchError:#{cmd} #{options}" if trace
  cmd = which(cmd) if which
  app = spawn cmd, options
  app.stdout.pipe(process.stdout)
  app.stderr.pipe(process.stderr)
  app.on 'exit', (status) ->
    callback? status

# ## *build*
#
# **given** optional boolean as watch
# **and** optional function as callback
# **then** invoke launch passing coffee command
# **and** defaulted options to compile src to lib
build = (watch, callback) ->
  if typeof watch is 'function'
    callback = watch
    watch = false

  options = ['-m', '-c', '-b', '-o' ]
  options = options.concat files
  options.unshift '-w' if watch
  async.parallel [
    (callback) -> launchError 'coffee', options,
      (error) ->
        if error
          out "error during compile #{error}.  no post_compile"
          callback error
        else
          post_compile -> callback error
    (callback) ->
      dest_dir = files[0]
      async.series [
        (callback) ->
          launchError 'cp', ['-v'].concat(copy_files.concat(dest_dir)), callback
        ,
        (callback) ->
          async.each copy_files, (source, callback) ->
            dest = path.join dest_dir, path.basename(source)
            launchError 'util/commit_stamp.sh', [source, dest], (error) ->
              callback error
        ],
        callback()

    ]
    ,
    callback

post_compile = (callback) ->
  out "post_compile: callback #{callback}" if trace
  dest_dir = files[0]
  sources = files[1..]
  async.each sources, (source, callback) ->
    filename = path.basename source, '.coffee'
    dest = path.join dest_dir, "#{filename}.js"
    launchError 'util/commit_stamp.sh', [source, dest], (error) ->
      out "post_compile: #{filename}, #{source}, #{dest}, e:#{error}" if trace
      callback error
  ,
  (error) ->
    "post_compile: async finished e:#{error}"
    callback error

# ## coffee watch not flexible enough, I want to run post filters
watch = (postbuild) ->
  task = "watch"
  out "#{task}: Watching for changes."
  _building = true

  build_done = (error) ->
    if postbuild?
      postbuild complete_build_done
    else
      complete_build_done error

  complete_build_done = (error) ->
    _building = false
    #console.error "#{task}: ", err if err?.length
    #out "#{task}: ", results if err?.length and results?.length
    out "#{task}: finished building e:#{error?}."

  change = (event, filename) ->
    out "#{task}.change: #{filename} #{event}"
    unless _building
      _building = true
      build false, build_done
    else
      out "#{task}.change: ignoring file watch, building in progress."

  source_files = files[1..]
  build false, (error) ->
    out "#{task}: first pass build finished." if verbose
    # wait for build to finish
    for file in source_files
      out "#{task}: start on file #{file}."
      try
        fs.watch file, persistent: true, change
      catch error
        console.error file, error
    if postbuild?
      postbuild ->
        build_done error
    else
      build_done error



# ## *unlinkIfCoffeeFile*
#
# **given** string as file
# **and** file ends in '.coffee'
# **then** convert '.coffee' to '.js'
# **and** remove the result
unlinkIfCoffeeFile = (file) ->
  if file.match /\.coffee$/
    fs.unlink file.replace('src','lib').replace(/\.coffee$/, '.js'), ->
    true
  else false

# ## *clean*
#
# **given** optional function as callback
# **then** loop through files variable
# **and** call unlinkIfCoffeeFile on each
clean = (callback) ->
  try
    for file in files
      unless unlinkIfCoffeeFile file
        walk file, (err, results) ->
          for f in results
            unlinkIfCoffeeFile f

    callback?()
  catch err

# ## *moduleExists*
#
# **given** name for module
# **when** trying to require module
# **and** not found
# **then* print not found message with install helper in red
# **and* return false if not found
moduleExists = (name) ->
  try
    require name
  catch err
    log "#{name} required: npm install #{name}", red
    false


# ## *mocha*
#
# **given** optional array of option flags
# **and** optional function as callback
# **then** invoke launch passing mocha command
mocha = (options, callback) ->
  #if moduleExists('mocha')
  if typeof options is 'function'
    callback = options
    options = []
  # add coffee directive
  options.push '--compilers'
  options.push 'coffee:coffee-script/register'
  out "mocha #{util.inspect options}" if verbose
  launchError 'mocha', options, callback

# ## *docco*
#
# **given** optional function as callback
# **then** invoke launch passing docco command
docco = (callback) ->
  #if moduleExists('docco')
  walk 'src', (err, files) -> launch 'docco', files, callback

############################################################
# google drive
#


option '-v', '--verbose', 'Print out more.'
option '-t', '--trace', 'Trace task invocation.'

verbose = false
trace = false

out = console.log.bind console

process_options = (options) ->
  if not verbose and options.verbose
    out "options: verbose"
    verbose = options.verbose?
    drivesync.verbose = verbose
  if not trace and options.trace
    out "options: trace"
    trace = options.trace?
    drivesync.trace = trace
  out "options: #{util.inspect options}" if verbose or trace

# ## *list*
list = (callback) ->
  out "list" if trace
  tasks = [
    (callback) ->
      drivesync.setupTokens callback
    drivesync.setupDrive
    drivesync.listProjects
    ]
  log "tasks #{util.inspect tasks}" if verbose
  async.waterfall tasks,
    (error, results, auth, client) ->
      if error
        out "error #{error}"
      else
        projects = results.items
        out "r:#{results?} a:#{auth?} c:#{client?}" if verbose
        out "#{util.inspect results, showHidden=false, depth=2}" if verbose
        l = ({ id: p.id, title: p.title } for p in projects)
        out "list projects(#{results.items.length}): \n#{util.inspect l}"
      callback? error, projects

ask = (question, format, callback) ->
  rl = readline.createInterface
    input: process.stdin
    output: process.stdout

  return rl.question "#{question}:", (data) ->
    data = data.toString().trim()
    rl.close()
    if format.test data
      return callback data
    else
      return ask "'#{data}' should match: #{format}\n" + question,
        format,
        callback

select = (projects, callback) ->
  prompt = []
  for project,index in projects
    prompt.push "#{index}: #{project.title}"
  prompt.push "select project "
  prompt = prompt.join '\n'
  r = (selection) ->
    project = projects[selection]
    out "##{selection} selected"
    out "project #{util.inspect project}"
    callback? null, projects[selection]
  #r 0
  ask prompt, /[0-9]+/, r

download = (projectMetadata, callback) ->
  out projectMetadata.title if verbose
  async.waterfall [
    (callback) ->
      drivesync.setupTokens callback
    (auth, callback) ->
      links = for type, link of projectMetadata.exportLinks
        link
      out "project links #{util.inspect links}." if verbose
      drivesync.downloadProject projectMetadata, links, auth, null, callback
    ],
    (error, project, auth, client, body) ->
      out "error #{error}" if error
      out "project #{util.inspect body}" if verbose
      fs.mkdir projectDownloadDir, (error) ->
        out "error #{error}" if error
        write = []
        for file in body.files
          type = typeToExtension file.type
          name = "#{file.name}.#{type}"
          dst = path.join projectDownloadDir, name
          out "filename #{name}" if verbose
          write.push { 'dest':dst, data:file.source}
        write.push {
          'dest': projectFile
          data: JSON.stringify body
          }
        out "write #{util.inspect write}" if trace
        async.each write, (file, callback) ->
          fs.writeFile file.dest, file.data, callback
          ,
          (error) ->
            if error
              out "error writing project #{error}"
            callback error, project, auth, client, body

upload = (meta, project, callback) ->
  projectID = meta.id
  out "upload to project #{projectID}" if trace
  async.waterfall [
    (callback) ->
      drivesync.setupTokens callback
    ,
    drivesync.setupDrive
    ,
    (auth, client, callback) ->
      out "map" if trace
      async.map project.files, (file, callback) ->
        filename = "#{file.name}.#{typeToExtension file.type}"
        id = file.id
        fullpath = path.join buildDir, filename
        out "uploading #{fullpath}"
        fs.readFile fullpath, 'utf8', (error, data) ->
          if error
            if error.code is 'ENOENT'
              out "error reading #{fullpath} #{error}, excluding" if verbose
              out "excluding #{fullpath}, file doesn't exist." if not verbose
              callback null, null
            else
              out "error reading #{fullpath} #{error}, fatal"
              callback error, null
          else
            out "read file #{fullpath} size #{data.length}." if trace
            file.source = data
            callback error, file
      ,
      (error, result) ->
        if error
          out "error during upload #{error} #{result}"
          callback error, result
        else
          files = files: result.filter (x) -> x
          json = JSON.stringify files
          drivesync.updateFile projectID, json, auth, client, (error, result) ->
            callback error, result
      ],
      (error, result) -> callback error, result

site = (callback) ->
  launch "jekyll", ['build', '--trace'], (e) ->
    out "site: #{e}."
    callback e


typeToExtension = (scriptType) ->
  t = scriptType
  t = googleType[scriptType] if scriptType of googleType
  return t



projectFileMap = (project) ->
  map = {}
  for file in project.files
    filename = "#{file.name}.#{typeToExtension file.type}"
    map[filename] = file.id
  return map

readProject = (callback) ->
  readJSON projectFile, callback

writeSelection = (project, callback) ->
  writeJSON selectionFile, project, callback

writeJSON = (file, data, callback) ->
  data = JSON.stringify data
  out data if verbose
  fs.writeFile file, data, (error) ->
    callback error, data

readSelection = (callback) ->
  readJSON selectionFile, callback

readJSON = (file, callback) ->
  out "readJSON #{file}" if trace
  fs.readFile file, (error, data) ->
    if error
      out "readJSON error #{error}" if trace
      callback error, null
    else
      out "readJSON #{data.length}" if trace
      json = JSON.parse data
      #out "readJSON #{util.inspect json}" if trace
      callback null, json
