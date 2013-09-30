# Description:
#   Register cron jobs to repeat Hubot commands.
#
# Commands:
#   hubot repeat[ help] - Show help text
#   hubot repeat (<crontab format>|daily|hourly) <command>[ as <name>] - Schedule a cron job to run a command
#   hubot show job(s| <id>) - List current cron jobs or just a specific one
#   hubot remove job <id> - Remove job
#   hubot clear jobs - Remove all jobs
#
# Dependencies:
#   "cron": "~1.0.1"

{CronJob} = require 'cron'
{TextMessage} = require 'hubot'

class ChronosJob
  @ACTIVE_JOBS = {}
  @BRAIN_KEY = 'chronosJobs'

  ####################################################
  # Static initialization to get a reference to the
  # Hubot and our key in its brain.
  ####################################################
  @init = (@robot) ->
    @robot.brain.data[@BRAIN_KEY] ||= {}
    @brain = @robot.brain.data[@BRAIN_KEY]
    @resurrect()


  ####################################################
  # Restore any previously-cached jobs.
  ####################################################
  @resurrect = ->
    new ChronosJob @unserialize job for id, job of @list()


  ####################################################
  # Fetch job data by ID.
  ####################################################
  @fetch = (id) ->
    @unserialize @brain[id]


  ####################################################
  # List all jobs' data.
  ####################################################
  @list = ->
    jobs = {}
    for own key, val of @brain
      jobs[key] = val

    jobs


  ####################################################
  # Remove a job by ID.
  ####################################################
  @remove = (id) ->
    @ACTIVE_JOBS[id]?.stop()
    delete @ACTIVE_JOBS[id]
    delete @brain[id]


  ####################################################
  # Remove all jobs.
  ####################################################
  @clear = ->
    @remove id for id in Object.keys(@list())


  ####################################################
  # Generate a unique job ID and try to keep it
  # as short as possible.
  ####################################################
  @generateJobId = ->
    # Try to use the smallest ID's that are free
    Object.keys(@ACTIVE_JOBS).filter (key) ->
      parseInt(key).toString().length is key.length
    .map (key) ->
      parseInt key
    .sort()
    .pop() + 1 || 1


  ####################################################
  # Transform cached job data into an object.
  ####################################################
  @unserialize: (data) ->
    try
      JSON.parse data
    catch


  ####################################################
  # Create a new Chronos job.
  #
  # Craetes the cron record and constructs a message
  # to send to Hubot.
  ####################################################
  constructor: ({@period, @jobId, @user, @command, @messageId}) ->
    @robot = @constructor.robot or throw new Error 'Need to initliaize with robot instance'

    recurringText = [@robot.name, @command].join(' ')
    @message = new TextMessage @user, recurringText, @messageId

    @jobId ?= @constructor.generateJobId()
    @start()


  ####################################################
  # Start a cron job. When the job stats, save a
  # reference to it and serialize its data into
  # the robot's brain.
  ####################################################
  start: ->
    jobInfo = """
      id: #{@jobId}
      period: #{@period}
      command: #{@command}
    """

    try
      @constructor.ACTIVE_JOBS[@jobId] = new CronJob
        start: true
        cronTime: @period
        onTick: =>
          @robot.receive @message

      @save()
      @robot.logger.info "Created job with info:\n#{jobInfo}"
    catch e
      @robot.logger.warn "Failed to creat job with info:\n#{jobInfo}"


  ####################################################
  # Save serialized data about the job into the brain.
  ####################################################
  save: ->
    @constructor.brain[@jobId] = @serialize()


  ####################################################
  # Serialize the job's data as JSON.
  ####################################################
  serialize: ->
    JSON.stringify {@period, @jobId, @user, @command, @messageId}


module.exports = (robot) ->
  ####################################################
  # Initialize ChronosJob when the robot's
  # brain is ready.
  ####################################################
  robot.brain.on 'loaded', ->
    ChronosJob.init robot


  ####################################################
  # Show help text.
  ####################################################
  robot.respond /repeat( help)?$/, (msg) ->
    msg.send """
      Use a cron pattern in by a command to run.
      For example, this would get me to say "hello world" every hour:

      repeat 0 * * * * echo hello world

      You can also use shorthand for hourly or daily tasks.

      repeat daily echo hello world every day
    """

  ####################################################
  # Create new scheduled jobs using either crontab
  # format or "daily"|"hourly". Optionally give the
  # job a custom name.
  #
  # `hubot repeat hourly echo hello world as chatter`
  ####################################################
  robot.respond /repeat (([-\d\*,\/]+ ){5}|daily |hourly )(.+)/i, (msg) ->
    now = new Date
    minutes = now.getUTCMinutes()
    hours = now.getUTCHours()

    period = msg.match[1]
      .trim()
      .replace('daily', "#{minutes} #{hours} * * *")
      .replace('hourly', "#{minutes} * * * *")

    command = msg.match[3]
    if name = command.match /as (.+)$/
      jobId = name[1]
      command = command.slice 0, -name[0].length

    if jobId and ChronosJob.fetch jobId
      return msg.send """
        There is already a job called #{jobId}.
        If you want to replace it, you should delete it with:
        remove job #{jobId}
      """

    msg.send """
      Adding command: #{command}
      It will run on this period: #{period}
      #{if jobId then "It will be called: #{jobId}" else ''}
    """

    {user, id} = msg.message
    new ChronosJob {period, command, user, jobId, messageId: id}


  ####################################################
  # List all jobs or a single job. Shows jobs' ID,
  # cron period, and command.
  ####################################################
  robot.respond /show job(s| .+)/, (msg) ->
    id = msg.match[1]

    displayJob = (job) ->
      "#{job.jobId}: #{job.period}, #{job.command}"

    msg.send if id is 's'
      Object.keys(ChronosJob.list())
      .map (id) ->
        displayJob ChronosJob.fetch(id)
      .join '\n'
    else if job = ChronosJob.fetch(id.trim())
      displayJob job
    else
      "That job doesn't exist yet"


  ####################################################
  # Delete an existing job if it exists.
  ####################################################
  robot.respond /remove job (.+)/, (msg) ->
    id = msg.match[1]
    ChronosJob.remove id
    msg.reply "Removing job: #{id}"


  ####################################################
  # Delete all existing jobs.
  ####################################################
  robot.respond /clear jobs/, (msg) ->
    msg.send "Removing #{Object.keys(ChronosJob.list()).length || 0} jobs"
    ChronosJob.clear()


####################################################
# Export the base class for unit tests
####################################################
module.exports.ChronosJob = ChronosJob
