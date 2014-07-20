chai = require 'chai'
chai.config.includeStack = true
should = chai.should()


describe 'isDateCurrent', ->
  library = null
  before ->
    library = require '../library'

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
    library.isDateCurrent(now, old).should.equal false
