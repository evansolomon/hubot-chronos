# Hubot Chronos

A cron-ish scheduling system for Hubot commands.

### Install
Not on NPM yet...

`npm install git://github.com/evansolomon/hubot-chronos.git`

### Details

Jobs are scheduled using [Node Cron](https://github.com/ncb000gt/node-cron) and cached in Hubot's brain. When the brain is loaded, cached jobs are resurrected. That means that if you use a persistent brain like Redis, jobs will persist across restarts. Yay, right?

Jobs can be scheduled using a standard cron pattern (`[minute] [hour] [day] [month] [year]`) using the `repeat` command. Everything following the cron pattern is treated a a Hubot command and automatically prefixed with the Hubot's name. You can give your scheudled job a custom ID by ending the commmand with "as [name]".

There are also helpers for the "daily" and "hourly" keywords. Each will set the command to recur every 1 or 24 hours starting from whenever you run the command.

### Example

Have Hubot say "hello world" every 2 minutes.

`hubot repeat */2 * * * * echo hello world`

Have Hubot PONG you every hour, and give the job a name

`hubot repeat hourly ping as status check`

See your running jobs

`hubot show jobs`

Remove a job by its ID

`hubot remove job status check`
