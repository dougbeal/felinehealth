setConfig = (name, value) ->
  config[name] = value
  properties.setProperty "config.#{name}", value
  verbose = value if name is 'verbose'
  trace = value if name is 'trace'


createSupportSheets = (spreadsheet) ->
  for i in ignoreSheets
    sheetName = ignoreSheets
    sheet = spreadsheet.getSheetByName(sheetName)
    spreadsheet.insertSheet sheetName  if sheet is null
  return

isIgnoreSheet = (name) ->
  name in ignoreSheets

registerSpreadsheetTrigger = (namespace) ->
  if spreadsheet isnt null
    triggers = ScriptApp.getProjectTriggers()
    for i of triggers
      ScriptApp.deleteTrigger triggers[i]
    prefix = ""
    prefix = "#{namespace}." if namespace
    properties.setProperty 'namespace', namespace
    ScriptApp.newTrigger(prefix + "edit").forSpreadsheet(spreadsheet)
    .onEdit().create()
    ScriptApp.newTrigger(prefix + "change").forSpreadsheet(spreadsheet)
    .onChange().create()
    ScriptApp.newTrigger(prefix + "initialize").forSpreadsheet(spreadsheet)
    .onOpen().create()

    enableTimeTrigger(namespace) if config.autoAddNewLines

    dump "triggers %s installed for %s", spreadsheet.getName(),
      ScriptApp.getProjectTriggers().map (item) ->
        item.getHandlerFunction()
    cacheSheetRows()
  else
    dump "spreadsheet was null, no triggers installed"
  flushLog()
  return

setupTimeTrigger = (functionName, namespace) ->
  namespace = properties.getProperty 'namespace' if not namespace?
  prefix = ""
  prefix = "#{namespace}." if namespace
  # run every 24 hours in local time zone? at 1am
  return ScriptApp.newTrigger(prefix + functionName)

enableTimeTrigger = (namespace)->
  setupTimeTrigger "onDaily", namespace
  .timeBased()
  .atHour 1
  .everyDays 1
  .create()
  dump "Enabling time trigger."
  return

testTimeTrigger = () ->
  setupTimeTrigger "onDaily"
  .timeBased()
  .after 1
  .create()
  dump "Enabling one shot test time trigger."
  return

testErrorTrigger = () ->
  setupTimeTrigger "generateError"
  .timeBased()
  .after 1
  .create()
  dump "Enabling one shot test time trigger."
  flushLog()
  return

chunkLog = (logString) ->
  logArray = logString.split '\n'
  return logArray.reduce (acc, item, index) ->
    group = Math.floor index / 5
    p = acc[group]
    acc[group] = "#{if p? then (p + '\n') else '' }#{item}"
    return acc
  ,
    []

flushLog = ->
  if verbose
    for row in chunkLog Logger.getLog()
      logSheet.appendRow [row]
    Logger.clear()
  return

logState = ->
  dump "logging state."
  sheets = spreadsheet.getSheets()
  for sheet in sheets
    rows = sheet.getMaxRows()
    name = sheet.getName()
    sid = sheet.getSheetId()
    if isIgnoreSheet name
      dump "ignore sheet %s:'%s' rows %s.", sid, name, rows
      continue
    crows = +properties.getProperty name
    dump "sheet %s:'%s' rows %s/%s.", sid, name, crows, rows
  dump "triggers %s installed for %s", spreadsheet.getName(),
    ScriptApp.getProjectTriggers().map (item) ->
      item.getHandlerFunction()
  dump "config %s", config
  dump "configDefinitions %s", configDefinitions
  dump properties.getProperty 'namespace'
  sheet = SpreadsheetApp.getActiveSheet()
  if sheet
    dump "active sheet %s", sheet.getName()
    dump "active range %s", sheet.getActiveRange()?.getA1Notation()
    dump "active column %s", sheet.getActiveRange()?.getColumn()
  else
    dump "no active sheet"
  flushLog()
  return

truncateLog = ->
  rows = logSheet.getMaxRows()
  logSheet.deleteRows 1, rows - 1

copyTemplate = ->
  template = 'BGTemplate'
  name = 'Blood Glucose'
  ss = SpreadsheetApp.getActive()
  source = ss.getSheetByName template
  year = new Date().getFullYear()
  copy = source.copyTo ss
  copy.setName "#{name} #{year}"
  ss.setActiveSheet copy
  ss.moveActiveSheet 1
  r = copy.getMaxRows()
  dest = copy.getRange "A#{r}"
  dest.setValue new Date()


catchAndLogError = (fn) ->
  return (args...) ->
    try
      fn(args...)
    catch error
      dumpError error

dumpError = (err) ->
  s = [err.toString()]
  s.push "name: " + err.name if err.name?
  s.push "\nstack: \n" + err.stack + "\n" if err.stack?
  for name, value of err
    s.push name + ": " + value
  s.join '\n'
  Logger.log s
  flushLog()

dump = ->
  Logger.log.apply Logger, arguments if verbose
  return

tdump = ->
  Logger.log.apply Logger, arguments if trace
  return

setupNewRow = (range) ->
  dest = range
  row = range.getRow()
  oldValue = dest.getValue()
  if oldValue is ""
    destFormat = spreadsheet.getRange "A#{row}:A"
    formatRow row
    dest.setValue new Date()
    dump "setupNewRow row %s - %s", row, dest.getA1Notation()
  else
    dump "FAILED - value already set %s - setupNewRow row %s - %s", oldValue,
      row, dest.getA1Notation()
  flushLog()
  return

isDateCurrent = (newDate, oldDate) ->
  if not oldDate?
    return false
  ny = newDate.getFullYear()
  oy = oldDate.getFullYear()
  nm = newDate.getMonth()
  om = oldDate.getMonth()
  nd = newDate.getDate()
  od = oldDate.getDate()
  return ny < oy or
    (ny == oy and
      (nm < om or
        (nm == om and
          (nd <= od))))

# A column contains current year/month/day or further in the future
isMaxRowCurrent = (sheet) ->
  n = new Date()
  cell  = "A#{sheet.getMaxRows()}"
  t = sheet.getRange(cell).getValue()
  dump "isMaxRowCurrent sheet '%s:%s' dates ['%s', '%s']",
    sheet.getName(), cell, n, t
  if t is ''
    return false
  else
    return isDateCurrent n, t

formatRow = (row) ->
  dest = spreadsheet.getRange "A#{row}:A"
  source = dest.offset -1, 0
  source.copyTo dest, formatOnly: true

addNewRow = (sheet) ->
  sheet.appendRow [new Date()]
  row = sheet.getMaxRows()
  formatRow row
  dump "addNewRow new and formatted %s", row

checkAndAddNewRow = ->
  ss = SpreadsheetApp.getActiveSpreadsheet()
  sheet = ss.getSheets()[0]
  dump "checkAndAddNewRow - examine date on sheet '%s'", sheet.getName()
  addNewRow sheet if not isMaxRowCurrent sheet
  flushLog()
  return


expireCache = ->
  sheets = spreadsheet.getSheets()
  for sheet in sheets
    name = sheets.getName()
    continue if isIgnoreSheet name
    properties.deleteProperty name
  dump "cleard cache."
  flushLog()
  return

cacheSheetRows = ->
  sheets = spreadsheet.getSheets()
  for sheet in sheets
    rows = sheet.getMaxRows()
    name = sheet.getName()
    sid = sheet.getSheetId()
    continue if isIgnoreSheet name
    properties.setProperty name, rows
    dump "sheet %s:'%s' rows %s.", sid, name, rows
  flushLog()
  return

toggleSidebar = ->
  sidebarOpen = false
  if sidebarOpen
    dump "closed sidebar from menu"
    google.script.host.close()
  else
    dump "opened sidebar from menu"
    SpreadsheetApp.getUi().showSidebar createSidebarHtml()
  flushLog()
  return

createSitebarTemplate = ->
  t = HtmlService.createTemplateFromFile 'sidebar.html'
  dump "getCode #{t.getCode()}" if verbose
  return t

createSidebarHtml = ->
  return createSitebarTemplate().evaluate()

emitConfig = ->
  html = []
  namespace = properties.getProperty 'namespace'
  for item in configDefinitions
    n = item.name
    d = item.desc
    v = config[n]
    tdump "#{n} #{d} #{v} #{typeof v}"
    html.push switch typeof v
      when 'boolean'
        """
        <div class="block">
          <input type="checkbox" name="config_#{n}" id="#{n}"
          #{"checked" if config[n]}
          onclick="google.script.run.containerCallbackShim(
            'configCheckboxToggle',
            '#{n}',
            this.checked);">
          </input>
          <label for=\"#{n}\">
            #{n}
          </lable>
            <div>
              #{d}
            </div>
        </div>
        """
      when 'number' then ""
      when 'string' then ""
  tdump "html #{html}"
  return html.join '\n'

configCheckboxToggle = (name, checked) ->
  checked = checked is 'true' if typeof checked is 'string'
  dump "n:%s c:%s", name, checked
  setConfig name, checked
  flushLog()


logEmitConfig = ->
  dump emitConfig()

runImmediateOnDaily = ->
  testTimeTrigger()

runOnOpen = ->
  onOpen()

rerunOnInstall = ->
  namespace = properties.getProperty 'namespace'
  dump "rerunOnInstall rerunning onInstall with namespace #{namespace}"
  onInstall namespace

initialize = (e) ->
  dump "initialize."
  cacheSheetRows()
  initializeMenus e
  return

initializeMenus = (e) ->
  namespace = properties.getProperty 'namespace'
  ui = SpreadsheetApp.getUi()



  menu = ui.createAddonMenu()
  menu.addItem 'Copy Template', "#{namespace}.copyTemplate"
  .addItem 'Show Config Sidebar', "#{namespace}.toggleSidebar"
  .addSeparator()

  smenu = null
  if config.developer
    smenu = menu
  else
    smenu = ui.createMenu('developer')

  smenu.addItem 'Log State', "#{namespace}.logState"
  .addItem 'Truncate Log', "#{namespace}.truncateLog"
  .addItem 'Log Emit Config', "#{namespace}.logEmitConfig"
  .addItem 'Time Trigger onDaily', "#{namespace}.runImmediateOnDaily"
  .addItem 'Run onOpen', "#{namespace}.runOnOpen"
  .addItem 'Re-run Install', "#{namespace}.rerunOnInstall"
  .addItem 'Time Trigger Error', "#{namespace}.testErrorTrigger"

  menu.addSubMenu smenu  if not config.developer

  menu.addToUi()


###
Event handlers
###
onInstall = catchAndLogError (namespace) ->
  dump "onInstall"
  registerSpreadsheetTrigger namespace
  onOpen()
  return

###
Automatically add new line
###
onDaily = catchAndLogError () ->
  dump "onDaily - possibly add new row"
  checkAndAddNewRow()
  return

generateError = catchAndLogError (event) ->
  dump "generateError %s", event
  foo
  flushLog()


###
Called onOpen
###
onOpen = catchAndLogError (e) ->
  dump "onOpen. e:'%s'", e
  initialize(e)
  if config.autoAddNewLines
    checkAndAddNewRow()
  flushLog()
  return

edit = catchAndLogError (e) ->
  sheet = e.source.getActiveSheet()
  sheetName = sheet.getSheetName()
  cachedRows = +properties.getProperty sheetName
  rows = sheet.getMaxRows()
  dump "onEdit range %s, name %s, event %s, rows %s, cached %s",
    e.range.getA1Notation(), sheetName, e, rows, cachedRows

  unless isIgnoreSheet sheetName
    column = e.range.getColumn()
    # don't worry about cached rows when value is set
    if e.value isnt null
      dump "onEdit - found value, considering column %s.", column
      if column is AM_U_COLUMN or column is PM_U_COLUMN
        offset = -1 if column is AM_U_COLUMN
        offset = 1 if column is PM_U_COLUMN
        # insert timestamp into offset
        targetRange = e.range.offset(0, offset)
        targetRange.setValue new Date() if targetRange.getValue() is ""
      else if column > AM_U_COLUMN and column < PM_U_COLUMN
        # insert note with timestamp
        targetRange = e.range
        note = targetRange.getNote()
        targetRange.setNote new Date() if note is ""
    if cachedRows is null
      cacheSheetRows()
      dump "onEdit - caching rows."
    else
      if cachedRows < rows
        tdump "onEdit - inserted, rows increased %s to %s.", cachedRows, rows
      else if rows is cachedRows
        tdump "onEdit - rows unchanged, %s column %s.", cachedRows, column
      else
        # deletion
        tdump "onEdit - rows deleted %s to %s.", cachedRows, rows

  #properties.setProperty(sheetName, rows);
  flushLog()
  return

change = catchAndLogError (e) ->
  dump "onChange - %s", e
  if e.changeType is "INSERT_ROW"
    change_INSERT_ROW()
  else if e.changeType is "REMOVE_ROW"
    change_REMOVE_ROW()
  flushLog()
  return

change_INSERT_ROW = () ->
  sheet = null
  name = null
  sid = null
  found = false
  for sheet in spreadsheet.getSheets()
    rows = sheet.getMaxRows()
    name = sheet.getName()
    sid = sheet.getSheetId()
    if isIgnoreSheet name
      dump "onChange INSERT_ROW - ignoring %s.", name
      continue
    cachedRows = +properties.getProperty name
    tdump "onChange INSERT_ROW #{name} r #{rows} c #{cachedRows}."
    if cachedRows? and rows isnt cachedRows
      # changed sheet found
      properties.setProperty name, rows
      found = true
      break
    else
      dump "onChange INSERT_ROW null cache - sheet %s:'%s' rows %s.",
        sid, name, rows  if cachedRows is null
  if found
    range = sheet.getRange "A#{rows}"
    dump "onChange INSERT_ROW - sheet %s:'%s' rows %s (%s) range %s.",
      sid, name, rows, cachedRows, range.getA1Notation()
    setupNewRow range
    ###
    #disabled in events
    dump "active range %s", sheet.getActiveRange()?.getA1Notation()
    sheet.setActiveRange range
    sheet.setActiveSelection range
    sheet = SpreadsheetApp.getActiveSheet()
    if sheet
      dump "active sheet %s", sheet.getName()
      dump "active range %s", sheet.getActiveRange()?.getA1Notation()
    else
      dump "no active sheet"
      ###
  else
    dump "onChange INSERT_ROW - failed to find sheet ."

change_REMOVE_ROW = () ->
  sheet = null
  name = null
  sid = null
  for sheet in spreadsheet.getSheets()
    rows = sheet.getMaxRows()
    name = sheet.getName()
    sid = sheet.getSheetId()
    continue  if isIgnoreSheet(name)
    cachedRows = +properties.getProperty(name)
    unless rows is cachedRows
      properties.setProperty name, rows
      dump "onChange REMOVE_ROW cached updated - sheet %s:'%s' rows %s (%s).",
        sid, name, rows, cachedRows
      break
    else
      dump "onChange REMOVE_ROW unchanged - sheet %s:'%s' rows %s (%s).",
        sid, name, rows, cachedRows

AM_U_COLUMN = 3
AM_BG_COLUMN = 4
PM_U_COLUMN = 28
PM_BG_COLUMN = AM_BG_COLUMN + 12

ignoreSheets = [
  "Log"
  "Config"
]
logSheetName = "Log"

configDefinitions = [
  name:'verbose'
  desc:'log to Log sheet'
  def:true
,
  name:'trace'
  desc:'detailed execution trace to Log sheet'
  def:true
,
  name:'autoAddNewLines'
  desc:'Turn off automatic adding of new lines to the first sheet'
  def:true
,
  name:'developer'
  desc:'Promote developer functions up a level in the menu'
  def:false
  ]

if SpreadsheetApp?
  spreadsheet = SpreadsheetApp.getActive()
  logSheet = spreadsheet.getSheetByName logSheetName
  properties = PropertiesService.getDocumentProperties()
  config = {}
  for item in configDefinitions
    name = item.name
    v = properties.getProperty "config.#{name}"
    if not v?
      v = item['def']
      properties.setProperty "config.#{name}", v
      v = properties.getProperty "config.#{name}"
    v = v is 'true'
    config[name] = v
  verbose = config['verbose']
  trace = config['trace']
else
  ###
  # exports for testing
  ###
  exports.isDateCurrent = isDateCurrent
  exports.chunkLog = chunkLog
  exports.catchAndLogError = catchAndLogError
  exports.generateError = generateError
  sinon = require 'sinon'
  exports.Logger = Logger =
    log: sinon.spy()
    clear: sinon.spy()
