# JOBS

JOBS provides a single of bash script (and a config file) that can be used to quickly schedule jobs on any machine that supplies a bash shell.

JOBS executes all created jobs in a FIFO order and guarantees that only the configured number of jobs are executed simultaneously.
Such a scheduling mechanism is required / helpful in case:

1. multiple processes should be executed with different runtimes (so starting them sequentially does not make sense)
2. only a limited number of processes should be started on the target machine (in order to not overload the machine and to ensure comparability of runtimes)
3. the maximum nunber of available / assigned processes should actually be used at all times to exploit all resources



## Scenario

We assume that there is a single server on which jobs should be executed.
All commands to JOBS can be executed from a remote machine or on the target executing machine itself.
In the following, we call the machine on which JOBS is running the **server**.
The machine that issues command to JOBS is called **client**, but of course both can be the same machine.


## Jobs

We consider every task that should be executed as a job.
When creating a job, we consider it to be *new*.
Jobs that have been created but should be exectued later can assume the state *stashed*.
While a job is executed, it is in the state *running*.
After the execution is terminated (or failed), the jobs has the state *done*.
Jobs that are done can also be moved to the *archive* to exclude them from certain statistics and lists.

	new [<-> stashed] -> running -> done [-> archive]

The jobs of each state are stored in a separate directory.
For each job, three files are created:

+ *.job* - the command that should be executed
+ *.log* - the log output of the execution
+ *.err* - the error output of the execution

Note than in *new* and *stashed*, there are only *.job* files.
In *running*, all three files (job, log, and err) are present for each job.
*done* and *archive* contain *.job* and *.log* for all jobs, *.err* is only kept in case the error output was not empty.

Each jobs is named by the timestamp (in nanoseconds) when it was created, e.g., *1423558075503400489*.
The respective files are then moved from one directory to the next as the state of the jobs changes:

	jobs.new/1423558075503400489.job
	-->
	jobs.running/1423558075503400489.err
	jobs.running/1423558075503400489.job
	jobs.running/1423558075503400489.log
	-->
	[jobs.done/1423558075503400489.err]
	jobs.done/1423558075503400489.job
	jobs.done/1423558075503400489.log
	-->
	[jobs.archive/1423558075503400489.err]
	jobs.archive/1423558075503400489.job
	jobs.archive/1423558075503400489.log


## Configuration File (jobs.cfg)


In the configuration file, names of directories and file extensions as well as the relevant server information are specified.
Most importantly, the number of jobs that JOBS should execute concurrently is specified.

	####################################################
	### hostname and directory of server running JOBS
	### directory without last '/'
	####################################################
	server_name="testServerName"
	server_dir="test/JOBS"

	####################################################
	### maximum number of concurrently executed jobs
	####################################################
	concurrent_jobs="10"

	####################################################
	### directory names for the different job states
	### directories without last '/'
	####################################################
	jobs_dir_new="jobs.new"
	jobs_dir_stashed="jobs.stashed"
	jobs_dir_running="jobs.running"
	jobs_dir_done="jobs.done"
	jobs_dir_archive="jobs.archive"

	####################################################
	### file extensions for jobs and log/error files
	####################################################
	extension_job=".job"
	extension_log=".log"
	extension_err=".err"

	####################################################
	### destination of main log output
	####################################################
	main_log="jobs.log"



## Script (jobs.sh) and Commands

JOBS is implemented in a single file to make deployment and execution simply.
Each command is executed as follows:

	> jobs.sh $command [$parameters]

The first parameter is always the command to be executed.
It is followed by command-specific parameters.

From the **client** side, the following commands are available:

+ Deployment
	+ deploy
+ Job Maintenance
	+ create
	+ stash
	+ unstash
	+ archive
	+ trash
+ Job Starting
	+ start
	+ execute
+ Getting Info
	+ status
	+ list
	+ info
	+ log

The commands as they are described here are all meant to be executed from the client.
Each command *$command* is then translated into a command *${command}Server* which is executed on the server passing the parameters accordingly.


### Deployment: deploy

	> jobs.sh deploy

This command deploy JOBS on the machine specified in the config file.
*jobs.sh* and *jobs.cfg* are synced to *$server_name:$server_dir* and the directories for new, running, done, and archived jobs are created.
The destination directors *$server_dir* is also created in case it does not exist already.

This command can also be used to update, e.g., the config file.


### Maintenance: create

	> jobs.sh create $task

The *create* command created a *new* job as specified by the task parameter.
Creating a job means to simply determine its id (as the current timestamp in nanoseconds) and create a file containing the task in the directory there new jobs are stored.

	> ./jobs.sh create ./myTask.sh
	created job '1423911119834276775' --> ./myTask.sh

Make sure to properly quote composite commands so that they can be processed correctly, e.g.,

	> ./jobs.sh create 'cd myDir; ./myTask.sh'
	created job '1423911119834276775' --> cd myDir; ./myTask.sh


### Maintenance: stash

	> jobs.sh stash

This command changes the state of all new jobs to be stashed.
This should not be confused with actually stashing running jobs.
It only means that these new jobs will not be executed next in case processes are free.

Stashing new jobs is usefull in case some intermediate jobs should be executed.
Since all jobs are executed in FIFO order, it would not be possible to simply move some jobs in between the existing queue of new jobs.
Hence, the workflow would be to stash all new jobs, create the intermediate ones, and let them be executed.
After these intermediate jobs are started, the currently stashed jobs can be moved back to the new state (unstashed).


### Maintenance: unstash

	> jobs.sh unstash

This command unstashed all previoudly stashed jobs, i.e., changes their state back to new.

Note that unstashing while there are still new (intermediate) jobs will put the currently new jobs at the end of the queue again (maintain FIFO order).
Hence, you need to make sure that all intermediate jobs have been started before unstashing the "old" new jobs again.


### Maintenance: archive

	> jobs.sh archive

This command moves all done jobs to the archive.
This does not have any influence the execution of the systems as the jobs are not considered any more anyways.
This command is usefull in case logs or error messages are of interest (e.g., usong the log command) but old jobs are not of interest and should be excluded from the lists and results.


### Maintenance: trash

	> jobs.sh trash

The *trash* command is used to delete all *new* jobs.
Its execution simply deletes all jobs from the new directory.

	> ./jobs.sh trash
	trashed 20 new jobs

It is usefull in case some jobs have been created by accident and that should not be executed.


### Job Starting: start

	> jobs.sh start

The *start* command start a new 'round' of execution.
It checks how many tasks are currently running.
In case less tasks are running than the maximum specified in the config file (i.e., *$concurrent_jobs*) new jobs are started (using the *startServer* command) until no new jobs are available or the maximum number of concurrently running jobs is reached.

It is recommend to simply create a cron job to execute this *start* command regularly, e.g., every minute.
An example of a crontab entry for starting it every minute would lokk like this:

	* * * * * cd ~/theJobsDir; ./jobs.sh startServer

Similar to the *execute* command, it can be executed from the client (*start*) but starting a round from the server is commonly the way to go (*startServer*).


### Job Starting: execute

	> jobs.sh execute $task_id

The *execute* command starts the execution of the job specified by the id given as parameter.
While *execute* can be executed from the client, it is mainly used by the *start* command to start new jobs.
Note that it is not sent to the background by itself, hence executing this command from the client blocks until the job is finished.


### Getting Info: status

	> jobs.sh status

This command output some statistics about the jobs currently managed by JOBS on the server.
In the following example, 13 jobs are new (i.e., waiting for execution).
3 jobs are running while the maximum of concurrent jobs is configured as 5.
Hence, during the next execution of *start / startServer*, the oldest 2 new jobs are started.
The execution of 6 jobs has been finished, for 1 of them the error output was not empty.
44 done jobs are located in the archive, 3 of which had some errors.

	new:     13
	running: 3 / 5
	done:    6 (1)
	archive: 44 (3)


### Getting Info: list

	> jobs.sh list $type
	> jobs.sh list (new|running|done|archive)

This command lists all jobs of a given type, i.e., either *new*, *done*, *running*, or *archive*.
This type is expected as a parameter.
Examples are as follows:

	> ./jobs.sh list new
	1423840572803298424.job
	1423840573235935154.job
	1423840573672117199.job
	1423840574069359164.job
	...
	
	> ./jobs.sh list done
	1423840576059658437.job
	1423840576460658483.job
	1423840576857206085.job
	...

This command only outputs the jobs, log and err files are excluded.


### Getting Info: info

	> jobs.sh info $task_id

Each job is identified by the timestamp (in nanoseconds) when it was created, e.g., 	*1423840572803298424.job* as in the example before.
Note that these ids can be retrieved using the *list* command but are also displayed when a new job is created.

The info command outputs some information about the task taking this id as a parameter.

In case of a new job, the task that should be executed is displayed:

	> ./jobs.sh info 1423840572803298424
	job '1423840572803298424' is new
	  -> cd myDir; ./myExecutable.sh

For done (and archived jobs), the task is displayed as well as the tail of error and log messages:

	> ./jobs.sh info 1423839439296664748
	job '1423839439296664748' is done
	  -> cd myDir; ./myExecutable.sh
	  ERR output (last -2 line)
	  ERR output (last -1 line)
	  ERR output (last line)
	  LOG output (last -2 line)
	  LOG output (last -1 line)
	  LOG output (last line)

For running jobs, the task and the tail of the error message is displayed.
Then, a *tail -f* on the log is performed.

	> ./jobs.sh info 1423839011692995957
	job '1423839011692995957' is running
	  -> cd myDir; ./myExecutable.sh
	  ERR output (last -2 line)
	  ERR output (last -1 line)
	  ERR output (last line)
	  LOG output (current line 1)
	  LOG output (current line 2)
	  LOG output (current line 3)
	  ...


### Getting Info: log

	> jobs.sh log $operation $type $file
	> jobs.sh log (cat|tail|tailf) (new|running|done|archive) (job|log|err)

Ths *log* command can be used to access the log, err, and job files of all jobs in a specific type.
The command takes 3 parameters: the *operation* to be performed, the job *type*, and the *file* to be accessed.
Hence, the name *log* is not perfectly accurate but it seemed more convenient than *displayCertainInformmationOfASpecificTaskType* :-)

The following 3 operations are available:

+ *cat* - output the complete files
+ *tail* - output only the tail of the files
+ *tailf* - perform a *tail -f* on the files

While *cat* and *tail* are usefull to get an overview over the contents of the specified files, *tailf* is especially interesting to see the log and err files as they are written.

The *type* can be any of the 4 job states (*new*, *running*, *done*, or *archive*).

The *file* parameter can be any of the 3 files available for each job (*job*, *log*, *err*).



## Log File

The location of the log file can be configured in the config file:

	main_log="jobs.log"

All output from **JOBS** generated during start and execution is written there.



## An Example

Here is just a small example of some commands to execute to create tasks and execute them afterwards.
It should be self-explanatory...

	> ./jobs.sh deploy
	
	==> on the server in test/
	> ls -l
	drwxr-xr-x jobs.archive
	-rw-r--r-- jobs.cfg
	drwxr-xr-x jobs.done
	drwxr-xr-x jobs.new
	drwxr-xr-x jobs.running
	-rwxr-xr-x jobs.sh
	
	> ./jobs.sh status
	new:     0
	running: 0 / 3
	done:    0 (0)
	archive: 0 (0)
	
	> ./jobs.sh create 'sleep 10; echo 1'
	created job '1423913192131041734' --> sleep 10; echo 1
	> ./jobs.sh create 'sleep 10; echo 2'
	created job '1423913194975705298' --> sleep 10; echo 2
	> ./jobs.sh create 'sleep 10; echo 3'
	created job '1423913197425530543' --> sleep 10; echo 3
	> ./jobs.sh create 'sleep 10; echo 4'
	created job '1423913199759544779' --> sleep 10; echo 4
	> ./jobs.sh create 'sleep 20; echo 5'
	created job '1423913207566017745' --> sleep 20; echo 5
	> ./jobs.sh create 'sleep 20; echo 6'
	created job '1423913209890181824' --> sleep 20; echo 6
	> ./jobs.sh create 'sleep 20; echo 7'
	created job '1423913213545051690' --> sleep 20; echo 7
	> ./jobs.sh create 'sleep 20; echo 8'
	created job '1423913216376944479' --> sleep 20; echo 8
	
	> ./jobs.sh status
	new:     8
	running: 0 / 3
	done:    0 (0)
	archive: 0 (0)
	
	> ./jobs.sh start
	
	./jobs.sh status
	new:     5
	running: 3 / 3
	done:    0 (0)
	archive: 0 (0)
	
	./jobs.sh status
	new:     5
	running: 0 / 3
	done:    3 (0)
	archive: 0 (0)

As noted before, logs from job execution and start are written to the main log file (jobs.log by default).
After the example, the content of the log file is the following:

	Sat Feb 14 12:29:06 CET 2015 - 0 jobs are RUNNING
	Sat Feb 14 12:29:06 CET 2015 - 8 jobs are NEW
	Sat Feb 14 12:29:07 CET 2015 - now, 0 jobs are RUNNING
	Sat Feb 14 12:29:08 CET 2015 - now, 0 jobs are RUNNING
	Sat Feb 14 12:29:09 CET 2015 - now, 0 jobs are RUNNING
	Sat Feb 14 12:29:10 CET 2015 - now, 0 jobs are RUNNING
	Sat Feb 14 12:29:11 CET 2015 - now, 0 jobs are RUNNING
	Sat Feb 14 12:29:12 CET 2015 - now, 0 jobs are RUNNING
	Sat Feb 14 12:29:13 CET 2015 - now, 0 jobs are RUNNING
	Sat Feb 14 12:29:14 CET 2015 - now, 0 jobs are RUNNING
	Sat Feb 14 12:29:54 CET 2015 - 0 jobs are RUNNING
	Sat Feb 14 12:29:54 CET 2015 - 8 jobs are NEW
	Sat Feb 14 12:29:55 CET 2015 - now, 0 jobs are RUNNING
	Sat Feb 14 12:29:56 CET 2015 - now, 0 jobs are RUNNING
	Sat Feb 14 12:29:57 CET 2015 - now, 0 jobs are RUNNING
	Sat Feb 14 12:29:58 CET 2015 - now, 0 jobs are RUNNING
	Sat Feb 14 12:29:59 CET 2015 - now, 0 jobs are RUNNING
	Sat Feb 14 12:30:00 CET 2015 - now, 0 jobs are RUNNING
	Sat Feb 14 12:30:01 CET 2015 - now, 0 jobs are RUNNING
	Sat Feb 14 12:30:02 CET 2015 - now, 0 jobs are RUNNING
	Sat Feb 14 12:30:23 CET 2015 - 0 jobs are RUNNING
	Sat Feb 14 12:30:23 CET 2015 - 8 jobs are NEW
	Sat Feb 14 12:30:23 CET 2015 - EXECUTING job 1423913192131041734 (sleep 10; echo 1)
	Sat Feb 14 12:30:24 CET 2015 - now, 1 jobs are RUNNING
	Sat Feb 14 12:30:24 CET 2015 - EXECUTING job 1423913194975705298 (sleep 10; echo 2)
	Sat Feb 14 12:30:25 CET 2015 - now, 2 jobs are RUNNING
	Sat Feb 14 12:30:25 CET 2015 - EXECUTING job 1423913197425530543 (sleep 10; echo 3)
	Sat Feb 14 12:30:26 CET 2015 - now, 3 jobs are RUNNING
	Sat Feb 14 12:30:26 CET 2015 - already 3 jobs running...
	Sat Feb 14 12:30:33 CET 2015 - DONE with job 1423913192131041734
	Sat Feb 14 12:30:34 CET 2015 - DONE with job 1423913194975705298
	Sat Feb 14 12:30:35 CET 2015 - DONE with job 1423913197425530543

The contents of the directories on the server then are the following:

	> ls -l test/

	-rw-r--r-- jobs.cfg
	-rw-r--r-- jobs.log
	-rwxr-xr-x jobs.sh

	jobs.archive:

	jobs.done:
	-rw-r--r--423913192131041734.job
	-rw-r--r--423913192131041734.log
	-rw-r--r--423913194975705298.job
	-rw-r--r--423913194975705298.log
	-rw-r--r--423913197425530543.job
	-rw-r--r--423913197425530543.log

	jobs.new:
	-rw-r--r--423913199759544779.job
	-rw-r--r--423913207566017745.job
	-rw-r--r--423913209890181824.job
	-rw-r--r--423913213545051690.job
	-rw-r--r--423913216376944479.job

	jobs.running:
