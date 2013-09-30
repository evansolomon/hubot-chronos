{EventEmitter} = require 'events'

hubot = require 'hubot'
class hubot.TextMessage
  constructor: (@user, @text, @id) ->

{ChronosJob} = require '../src/chronos'

should = require 'should'

class RobotShim extends EventEmitter
  constructor: ->
    @name = 'Chronos'
    @brain =
      data: {}

  receive: (msg) ->
    @emit 'receive', msg

  logger:
    warn: ->
    info: ->


chronosArgs = ->
  period: '0 * * * *'
  user:
    room: 'greece'
    name: 'Father Time'
    id: '-5000'

describe 'Export', ->
  it 'Should export a class', ->
    should.exist ChronosJob

describe 'Initialization', ->
  it 'Should require a robot instance', ->
    (-> new ChronosJob {}).should.throw 'Need to initliaize with robot instance'

    robot = new RobotShim
    ChronosJob.init robot
    (-> new ChronosJob {}).should.not.throw()

describe 'Creating jobs', ->
  it 'Should increment job IDs', ->
    first = new ChronosJob chronosArgs()
    second = new ChronosJob chronosArgs()

    first.jobId.should.be.below second.jobId

  it 'Should accept custom job IDs', ->
    args = chronosArgs()
    args.jobId = 'spawn head'
    job = new ChronosJob args
    job.jobId.should.equal 'spawn head'

  it 'Should reject invalid cron patterns', ->
    args = chronosArgs()
    args.period = 'not a cron pattern'
    job = new ChronosJob args
    should.not.exist ChronosJob.brain[job.jobId]

  it 'Should cache valid jobs', ->
    job = new ChronosJob chronosArgs()
    ChronosJob.fetch(job.jobId).should.have.keys [
      'period'
      'jobId'
      'user'
    ]

    ChronosJob.ACTIVE_JOBS[job.jobId].start.should.be.instanceof Function
    ChronosJob.ACTIVE_JOBS[job.jobId].stop.should.be.instanceof Function

describe 'Managing job state', ->
  before ->
    ChronosJob.clear()
    new ChronosJob chronosArgs()
    new ChronosJob chronosArgs()
    new ChronosJob chronosArgs()

  it 'Should list jobs', ->
    ChronosJob.list().should.have.keys '1', '2', '3'

  it 'Should fetch specific jobs', ->
    ChronosJob.fetch('2').should.be.ok
    should.not.exist ChronosJob.fetch('20')

  it 'Should remove jobs', ->
    ChronosJob.remove('3')
    ChronosJob.list().should.have.keys '1', '2'

  it 'Should remove all jobs', ->
    ChronosJob.clear()
    Object.keys(ChronosJob.list()).length.should.equal 0

  it 'Should serialize and unserialize jobs', ->
    job = new ChronosJob chronosArgs()

    serialized = job.serialize()
    ChronosJob.unserialize(serialized).should.be.ok

    newJob = new ChronosJob ChronosJob.unserialize(serialized)
    newJob.jobId.should.equal job.jobId

