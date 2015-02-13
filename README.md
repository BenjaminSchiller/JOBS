# JOBS

JOBS provides a small set of bash scripts that can be used to quickly schedule jobs on any machine that supplies a bash shell.

JOBS executes all created jobs in a FIFO order and guarantees that only the configured number of jobs are executed simultaneously.
This is helpful in case many processes with potentially different runtimes need to be executed but the machine should not be overloaded BUT the maximum number of available processors should be exhausted.


## Scenario

We assume that there is a server on which jobs should be executed.
All commands to JOBS can be executed from a remote machine or on the target executing machine itself.
In the following, we call the machine on which JOBS is running the **server**.
The machine that issues command to JOBS is called **client**, but of course both can be the same machine.


## Jobs

We consider every task that should be executed as a job.
When creating a job, we consider it to be *new*.
While it is executed, it is in the state *running*.
After the execution is terminated, the jobs has the state *done*.
Jobs that are done can also be moved to the *archive* which marks the fourth possible state.

	new --> running --> done [--> archive]

The jobs of each state are stored in a separate directory.
For each job, three files are created:

+ *.job* - the command that should be executed
+ *.log* - the log output of the execution
+ *.err* - the error output of the execution

Note than in *new*, there are only *.job* files.
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
	####################################################
	server_name="testServerName"
	server_dir="test/JOBS"

	####################################################
	### maximum number of concurrently executed jobs
	####################################################
	concurrent_jobs="10"

	####################################################
	### directory names for the different job states
	####################################################
	jobs_dir_new="jobs.new"
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



## Script (jobs.sh)

JOBS is implemented in a single file to make deployment and execution simply.
Each command is executed as follows:

	> jobs.sh $command [$parameters]

The first parameter is always the command to be executed.
It is followed by command-specific parameters.

From the **client** side, the following commands are available:

+ status
+ archive
+ info
+ list
+ log
+ create
+ trash

### Command: status

	> jobs.sh status

### Command: archive

	> jobs.sh archive

### Command: info

	> jobs.sh info $task_id

### Command: list

	> jobs.sh list $type
	> jobs.sh list (new|running|done|archive)

### Command: log

	> jobs.sh log $operation $type $file
	> jobs.sh log (cat|tail|tailf) (new|running|done|archive) (job|log|err)

### Command: create

	> jobs.sh create $command

### Command: trash

	> jobs.sh trash