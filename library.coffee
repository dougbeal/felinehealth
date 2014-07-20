createSupportSheets = (spreadsheet) ->
  for i in ignoreSheets
    sheetName = ignoreSheets
    sheet = spreadsheet.getSheetByName(sheetName)
    spreadsheet.insertSheet sheetName  if sheet is null
  return

readConfig = ->
  rawConfig = spreadsheet.getSheetByName("Config").getRange("A1:B").getValues()
  for item in rawConfig
    k = item[0]
    v = item[1]
    if k isnt "" and v isnt ""
      config[k] = v
      properties.setProperty "config." + k, v
  config["init"] = true
  verbose = config["verbose"]
  trace = config["trace"]
  Logger.log "readConfig %s", config
  flushLog()
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
    dump "triggers %s installed for %s", spreadsheet.getName(),
      ScriptApp.getProjectTriggers().map (item) ->
        item.getHandlerFunction()
    cacheSheetRows()
  else
    dump "spreadsheet was null, no triggers installed"
  flushLog()
  return

flushLog = ->
  if verbose
    logSheet.appendRow [Logger.getLog()]
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
    crows = properties.getProperty name
    dump "sheet %s:'%s' rows %s/%s.", sid, name, crows, rows
  dump "triggers %s installed for %s", spreadsheet.getName(),
    ScriptApp.getProjectTriggers().map (item) ->
      item.getHandlerFunction()
  dump "config %s", config
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

dump = ->
  Logger.log.apply Logger, arguments if verbose
  return

tdump = ->
  Logger.log.apply Logger, arguments if trace
  return

insertRowEvent = (range) ->
  setupNewRow range
  return

setupNewRow = (range) ->
  dest = range
  row = range.getRow()
  oldValue = dest.getValue()
  if oldValue is ""
    destFormat = spreadsheet.getRange "A#{row}:A"
    sourceFormat = dest.offset -1, 0
    sourceFormat.copyTo destFormat, formatOnly: true
    dest.setValue new Date()
    dump "setupNewRow row %s - %s", row, dest.getA1Notation()
  else
    dump "FAILED - value already set %s - setupNewRow row %s - %s", oldValue,
      row, dest.getA1Notation()
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

initialize = (e) ->
  dump "initialize."
  readConfig()
  cacheSheetRows()
  initializeMenus e
  return

initializeMenus = (e) ->
  namespace = properties.getProperty 'namespace'
  ui = SpreadsheetApp.getUi()
  menu = ui.createAddonMenu()
  menu.addItem 'Log State', "#{namespace}.logState"
  .addToUi()
  menu.addItem 'Truncate Log', "#{namespace}.truncateLog"
  .addToUi()
  menu.addItem 'Template to New Year', "#{namespace}.copyTemplate"
  .addToUi()


###
Event handlers
###
onInstall = (namespace) ->
  dump "onInstall"
  readConfig()
  registerSpreadsheetTrigger namespace
  return

###
Called onOpen
###
onOpen = (e) ->
  dump "onOpen."
  initialize(e)
  return

edit = (e) ->
  sheet = e.source.getActiveSheet()
  sheetName = sheet.getSheetName()
  cachedRows = properties.getProperty sheetName
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
        dump "onEdit - inserted, rows increased %s to %s.", cachedRows, rows
      else if rows is cachedRows
        dump "onEdit - rows unchanged, %s column %s.", cachedRows, column
      else
        # deletion
        dump "onEdit - rows deleted %s to %s.", cachedRows, rows

  #properties.setProperty(sheetName, rows);
  flushLog()
  return

change = (e) ->
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
    insertRowEvent  range
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
spreadsheet = SpreadsheetApp.getActive()
logSheet = spreadsheet.getSheetByName logSheetName
properties = PropertiesService.getDocumentProperties()
config = {}
verbose = properties.getProperty "config.verbose"
trace = properties.getProperty "config.trace"
if verbose is null or trace is null
  readConfig()
