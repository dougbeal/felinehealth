util = require 'util'
chai = require 'chai'
sinon = require 'sinon'
sinonChai = require "sinon-chai"

chai.config.includeStack = true
should = chai.should()
chai.use sinonChai

describe 'isDateCurrent', ->
  library = null
  before ->
    library = require '../build/library'

  it 'same date returns true', ->
    date = new Date 2014,1,1
    library.isDateCurrent(date, date).should.equal true

  it 'same date with time returns true', ->
    date = new Date()
    date.setYear 2014
    date.setMonth 1
    date.setDate 1
    library.isDateCurrent(date, date).should.equal true


  it 'same date with different hours returns true', ->
    date = new Date()
    date.setYear 2014
    date.setMonth 1
    date.setDate 1
    date.setHours(0)
    date2 = new Date(date)
    date2.setHours(1)
    library.isDateCurrent(date, date2).should.equal true
    library.isDateCurrent(date2, date).should.equal true

  it 'old +1 year always returns true', ->
    now = new Date 2014,1,1
    old = new Date 2015,1,1
    library.isDateCurrent(now, old).should.equal true
    now = new Date 2014,3,1
    old = new Date 2015,1,1
    library.isDateCurrent(now, old).should.equal true
    now = new Date 2014,3,1
    old = new Date 2015,5,1
    library.isDateCurrent(now, old).should.equal true


  it 'old -1 year returns false', ->
    now = new Date 2014,1,1
    old = new Date 2013,1,1
    library.isDateCurrent(now, old).should.equal false

  it 'old -1 month returns false', ->
    now = new Date 2013,2,1
    old = new Date 2013,1,1
    library.isDateCurrent(now, old).should.equal false

  it 'old -1 day returns false', ->
    now = new Date 2013,1,2
    old = new Date 2013,1,1
    library.isDateCurrent now, old
    .should.equal false

describe 'chunkLog', ->
  library = null
  before ->
    library = require '../build/library'

  it 'chunk empty string', ->
    library.chunkLog ''
    .should.be.array

  it 'chunk single space string', ->
    library.chunkLog ' '
    .should.be.array

  it 'chunk single newline string', ->
    library.chunkLog '\n'
    .should.be.array

  it 'chunk one line string', ->
    library.chunkLog 'foo'
    .should.be.array

  it 'chunk two line string', ->
    r = library.chunkLog 'foo\nbar'
    r.should.be.array
    r.should.have.length 1

  it 'chunk 6 line string', ->
    r = library.chunkLog [0..5].join '\n'
    r.should.be.array
    r.should.have.length 2

  for count in [0..25]
    it "chunk #{count} line string", do (count) -> ->
      ar = [0..count].join '\n'
      r = library.chunkLog ar
      r.should.be.array
      r.should.have.length Math.floor(count / 5) + 1

describe 'catchAndLogError', ->
  library = null
  before ->
    library = require '../build/library'

  beforeEach ->
    library.Logger.log.reset()
    library.Logger.clear.reset()


  it 'should catch error', ->
    generateError = library.catchAndLogError (event) ->
      foo
    generateError()
    library.Logger.log.should.have.been.called

  it 'should log error', ->
    error = new Object()
    s = 'Fakir'
    error.toString = -> s
    generateError = library.catchAndLogError (event) ->
      throw error
    generateError()
    library.Logger.log.should.have.been.called
    library.Logger.log.getCall(0).args[0].should.contain s

  it 'should catch error and pass arguments', ->
    generateError = library.catchAndLogError (event) ->
      event.not.undefined
      event.equals "event"
      foo
    generateError "event"
    library.Logger.log.should.have.been.called


  it 'should pass arguments', ->
    generateError = library.catchAndLogError (event) ->
      event.undefined
      event.equals "event"
    generateError "event"


  it 'should pass many arguments', ->
    generateError = library.catchAndLogError (one, two, three, four) ->
      event.undefined
      event.equals "event"
    generateError [1..4]...

  it 'should call spy', ->
    spy = sinon.spy()
    generateError = library.catchAndLogError spy
    generateError "event"
    spy.should.have.been.called
