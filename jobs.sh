#!/bin/bash

source jobs.cfg


if [[ -z "$processors_list" ]]; then
	processors_list=($(seq $processors_start $processors_end))
fi





if [[ $1 = "deploy" ]]; then
	echo "deploy to $server_name:$server_dir"
	ssh $server_name "if [[ ! -d $server_dir ]]; then mkdir -p $server_dir; fi; \
		if [[ ! -d $server_dir/$jobs_dir_new ]]; then mkdir -p $server_dir/$jobs_dir_new; fi; \
		if [[ ! -d $server_dir/$jobs_dir_stashed ]]; then mkdir -p $server_dir/$jobs_dir_stashed; fi; \
		if [[ ! -d $server_dir/$jobs_dir_running ]]; then mkdir -p $server_dir/$jobs_dir_running; fi; \
		if [[ ! -d $server_dir/$jobs_dir_done ]]; then mkdir -p $server_dir/$jobs_dir_done; fi; \
		if [[ ! -d $server_dir/$jobs_dir_archive ]]; then mkdir -p $server_dir/$jobs_dir_archive; fi; \
		if [[ ! -d $server_dir/$jobs_dir_processors ]]; then mkdir -p $server_dir/$jobs_dir_processors; fi"
	rsync -auvzl jobs.{cfg,sh} $server_name:$server_dir/
	echo "done"
	exit
fi




if [[ $1 = "status" ]] || [[ $1 = "st" ]]; then
	ssh $server_name "cd $server_dir; ./jobs.sh statusServer"
	exit
fi

if [[ $1 = "statusServer" ]]; then
	count_new=$(ls $jobs_dir_new | grep $extension_job | wc -l)
	count_stashed=$(ls $jobs_dir_stashed | grep $extension_job | wc -l)
	count_running=$(ls $jobs_dir_running | grep $extension_job | wc -l)
	using=($(ls $jobs_dir_processors))
	count_done=$(ls $jobs_dir_done | grep $extension_job | wc -l)
	count_done_failed=$(ls $jobs_dir_done | grep $extension_err | wc -l)
	count_archive=$(ls $jobs_dir_archive | grep $extension_job | wc -l)
	count_archive_failed=$(ls $jobs_dir_archive | grep $extension_err | wc -l)
	echo "new:     $count_new ($count_stashed)"
	echo "running: $count_running / $concurrent_jobs (#: ${#processors_list[@]})"
	echo "done:    $count_done ($count_done_failed)"
	echo "archive: $count_archive ($count_archive_failed)"
	echo "using:   [${using[@]}]"
	echo "avail:   [${processors_list[@]}]"
	exit
fi





if [[ $1 = "archive" ]]; then
	ssh $server_name "cd $server_dir; ./jobs.sh archiveServer"
	exit
fi

if [[ $1 = "archiveServer" ]]; then
	count_jobs=$(ls $jobs_dir_done | grep $extension_job | wc -l)
	if [[ $count_jobs > 0 ]]; then
		mv $jobs_dir_done/* $jobs_dir_archive/
		echo "archived $count_jobs done jobs"
	else
		echo "no done jobs to archive"
	fi
	exit
fi





if [[ $1 = "stash" ]]; then
	ssh $server_name "cd $server_dir; ./jobs.sh stashServer"
	exit
fi

if [[ $1 = "stashServer" ]]; then
	count_jobs=$(ls $jobs_dir_new | grep $extension_job | wc -l)
	if [[ $count_jobs > 0 ]]; then
		mv $jobs_dir_new/* $jobs_dir_stashed/
		echo "stashed $count_jobs new jobs"
	else
		echo "no new jobs to stash"
	fi
	exit
fi





if [[ $1 = "unstash" ]]; then
	ssh $server_name "cd $server_dir; ./jobs.sh unstashServer"
	exit
fi

if [[ $1 = "unstashServer" ]]; then
	count_jobs=$(ls $jobs_dir_stashed | grep $extension_job | wc -l)
	if [[ $count_jobs > 0 ]]; then
		mv $jobs_dir_stashed/* $jobs_dir_new/
		echo "unstashed $count_jobs stashed jobs"
	else
		echo "no stashed jobs to unstash"
	fi
	exit
fi







if [[ $1 = "info" ]]; then
	ssh $server_name "cd $server_dir; ./jobs.sh infoServer $2"
	exit
fi

if [[ $1 = "infoServer" ]]; then
	if [[ -e $jobs_dir_new/$2$extension_job ]]; then
		job=$(cat $jobs_dir_new/$2$extension_job)
		echo "job '$2' is new"
		echo "  -> $job"
	elif [[ -e $jobs_dir_running/$2$extension_job ]]; then
		jobs=$(cat $jobs_dir_running/$2$extension_job)
		echo "job '$2' is running"
		echo "  -> $job"
		if [[ -e $jobs_dir_running/$2$extension_err ]]; then
			tail $jobs_dir_running/$2$extension_err
		else
			echo "no ERR file"
		fi
		tail -f $jobs_dir_running/$2$extension_log
	elif [[ -e $jobs_dir_done/$2$extension_job ]]; then
		job=$(cat $jobs_dir_done/$2$extension_job)
		echo "job '$2' is done"
		echo "  -> $job"
		if [[ -e $jobs_dir_done/$2$extension_err ]]; then
			tail $jobs_dir_done/$2$extension_err
		else
			echo "no ERR file"
		fi
		tail $jobs_dir_done/$2$extension_log
	elif [[ -e $jobs_dir_archive/$2$extension_job ]]; then
		job=$(cat $jobs_dir_archive/$2$extension_job)
		echo "job '$2' is archived"
		echo "  -> $job"
		if [[ -e $jobs_dir_archive/$2$extension_err ]]; then
			tail $jobs_dir_archive/$2$extension_err
		else
			echo "no ERR file"
		fi
		tail $jobs_dir_archive/$2$extension_log
	else
		echo "could not find job '$2'"
	fi
	exit
fi



if [[ $1 = "list" ]]; then
	ssh $server_name "cd $server_dir; ./jobs.sh listServer $2"
	exit
fi

if [[ $1 = "listServer" ]]; then
	if [[ $2 = "new" ]]; then
		for job in $(ls $jobs_dir_new | grep $extension_job); do
			echo "$job -> $(cat $jobs_dir_new/$job)"
			echo "--> $(cat $jobs_dir_new/$job | wc -l | xargs) line"
		done
	elif [[ $2 = "stashed" ]]; then
		for job in $(ls $jobs_dir_stashed | grep $extension_job); do
			echo "$job -> $(cat $jobs_dir_stashed/$job)"
		done
	elif [[ $2 = "running" ]]; then
		for job in $(ls $jobs_dir_running | grep $extension_job); do
			echo "$job -> $(cat $jobs_dir_running/$job)"
		done
	elif [[ $2 = "done" ]]; then
		for job in $(ls $jobs_dir_done | grep $extension_job); do
			echo "$job -> $(cat $jobs_dir_done/$job)"
		done
	elif [[ $2 = "archive" ]]; then
		for job in $(ls $jobs_dir_archive | grep $extension_job); do
			echo "$job -> $(cat $jobs_dir_archive/$job)"
		done
	elif [[ $2 = "done_err" ]]; then
		for err in $(ls $jobs_dir_done | grep $extension_err); do
			job="${err/$extension_err/$extension_job}"
			echo "$job -> $(cat $jobs_dir_done/$job)"
			tail "$jobs_dir_done/$err"
			echo ""
		done
	elif [[ $2 = "archive_err" ]]; then
		for err in $(ls $jobs_dir_archive | grep $extension_err); do
			job="${err/$extension_err/$extension_job}"
			echo "$job -> $(cat $jobs_dir_archive/$job)"
			tail "$jobs_dir_archive/$err"
			echo ""
		done
	else
		echo "invalid job type '$2'"
		echo "  should be: new, stashed, running, done, archive"
		echo "         or: done_err, archive_err"
	fi
	exit
fi









if [[ $1 = "log" ]]; then
	ssh $server_name "cd $server_dir; ./jobs.sh logServer $2 $3 $4"
	exit
fi

if [[ $1 = "logServer" ]]; then
	if [[ $3 = "new" ]]; then
		dir=$jobs_dir_new
	elif [[ $3 = "running" ]]; then
		dir=$jobs_dir_running
	elif [[ $3 = "done" ]]; then
		dir=$jobs_dir_done
	elif [[ $3 = "archive" ]]; then
		dir=$jobs_dir_archive
	else
		echo "invalid type (new, running, done, archive)"
		exit 1
	fi

	if [[ $4 = "job" ]]; then
		extension=$extension_job
	elif [[ $4 = "log" ]]; then
		extension=$extension_log
	elif [[ $4 = "err" ]]; then
		extension=$extension_err
	else
		echo "invalid extension (job, log, err)"
		exit 1
	fi

	if [[ $2 = "cat" ]]; then
		cat $dir/*$extension
	elif [[ $2 = "tail" ]]; then
		tail $dir/*$extension
	elif [[ $2 = "tailf" ]]; then
		tail -f $dir/*$extension
	else
		echo "invalid operation (cat, tail, tailf)"
		exit 1
	fi
	exit
fi







if [[ $1 = "create" ]]; then
	ssh $server_name "cd $server_dir; ./jobs.sh createServer '${@:2}'"
	exit
fi

if [[ $1 = "createServer" ]]; then
	id=$(date +%s%N)
	printf "${@:2}\n" > ${jobs_dir_new}/$id${extension_job}
	echo "created job '$id' --> ${@:2}"
	exit
fi




if [[ $1 = "bulkCreate" ]]; then
	if [[ ! -f $2 ]]; then
		echo "bulk file $2 does not exists"
		exit
	fi
	rsync -auzl $2 ${server_name}:${server_dir}/
	ssh $server_name "cd $server_dir; ./jobs.sh bulkCreateServer '$2'"
	exit
fi

if [[ $1 = "bulkCreateServer" ]]; then
	while IFS='' read -r line || [[ -n "$line" ]]; do
		id=$(date +%s%N)
		while [[ $id = $lastId ]]; do id=$(date +%s%N); done
		if [[ $line = "" ]]; then continue; fi
		printf "$line\n" > ${jobs_dir_new}/$id${extension_job}
		echo "created job '$id' --> $line"
		lastId=$id
	done < $2
	exit
fi







if [[ $1 = "trash" ]]; then
	ssh $server_name "cd $server_dir; ./jobs.sh trashServer $2"
	exit
fi

if [[ $1 = "trashServer" ]]; then
	if [[ $2 = "new" ]]; then
		count_jobs=$(ls $jobs_dir_new | wc -l)
		if [[ $count_jobs > 0 ]]; then
			rm $jobs_dir_new/*
			echo "trashed $count_jobs new jobs"
		else
			echo "no new jobs to trash"
		fi
	elif [[ $2 = "done" ]]; then
		count_jobs=$(ls $jobs_dir_done | wc -l)
		if [[ $count_jobs > 0 ]]; then
			rm $jobs_dir_done/*
			echo "trashed $count_jobs done jobs"
		else
			echo "no done jobs to trash"
		fi
	elif [[ $2 = "archive" ]]; then
		count_jobs=$(ls $jobs_dir_archive | wc -l)
		if [[ $count_jobs > 0 ]]; then
			rm $jobs_dir_archive/*
			echo "trashed $count_jobs archived jobs"
		else
			echo "no archived jobs to trash"
		fi
	elif [[ $2 = "stashed" ]]; then
		count_jobs=$(ls $jobs_dir_stashed | wc -l)
		if [[ $count_jobs > 0 ]]; then
			rm $jobs_dir_stashed/*
			echo "trashed $count_jobs stashed jobs"
		else
			echo "no stashed jobs to trash"
		fi
	else
		echo "invalid job type '$2' for trashing"
		echo "  should be: new, done, archive, stashed"
	fi
	exit
fi





if [[ $1 = "execute" ]]; then
	ssh $server_name "cd $server_dir; ./jobs.sh executeServer $2"
	exit
fi

if [[ $1 = "executeServer" ]]; then
	if [[ $# -eq 2 ]]; then
		id=$2
	else
		echo "parameter taskID expected"
		exit 1
	fi

	job_new=$jobs_dir_new/$id$extension_job
	job_running=$jobs_dir_running/$id$extension_job
	job_done=$jobs_dir_done/$id$extension_job

	log_running=$jobs_dir_running/$id$extension_log
	log_done=$jobs_dir_done/$id$extension_log
	err_running=$jobs_dir_running/$id$extension_err
	err_done=$jobs_dir_done/$id$extension_err

	if [[ ! -e $job_new ]]; then
		echo "job '$id' does not exist"
		echo "$job_new"
		exit 1
	fi

	first=$(head -n 1 $job_new)
	if [[ $first =~ ^[-+]?[0-9]+$ ]]; then
		# use first line as number of processors
		processors_required=$first
	else
		# use number of lines as number of processors
		processors_required=$(cat $job_new | wc -l)
	fi

	echo "require $processors_required processors"
	free_processors=()
	for p in ${processors_list[@]}; do
		if [[ ! -f $jobs_dir_processors/$p ]]; then
			free_processors[${#free_processors[@]}]=$p
			if [[ ${#free_processors[@]} == $processors_required ]]; then
				echo "found free processors: ${free_processors[@]}"
				break
			fi
		fi
	done

	# exit if not enough processors available
	if [[ ${#free_processors[@]} -lt $processors_required ]]; then
		echo "not enough processors available (require $processors_required, found ${#free_processors[@]})"
		exit 1
	fi

	echo "$(date) - EXECUTING job $id on processors ${free_processors[@]} (1: $(cat $job_new | head -n 1))"
	i="1"
	for p in ${free_processors[@]}; do
		./jobs.sh "executeSubServer" $id $i $p &
		i=$((i+1))
	done

	sleep 0.5

	rm $job_new
	echo "$(date) - DONE starting job $id"

	exit
fi

if [[ $1 = "executeSubServer" ]]; then
	if [[ $# -eq 4 ]]; then
		id=$2
		index=$3
		processor=$4
	else
		echo "parameters taskID, index, and processorID expected"
		exit 1
	fi

	job_main=$jobs_dir_new/${id}${extension_job}

	processor_file=${jobs_dir_processors}/${processor}

	job_running=${jobs_dir_running}/${id}.${index}${extension_job}
	log_running=${jobs_dir_running}/${id}.${index}${extension_log}
	err_running=${jobs_dir_running}/${id}.${index}${extension_err}

	job_done=${jobs_dir_done}/${id}.${index}${extension_job}
	log_done=${jobs_dir_done}/${id}.${index}${extension_log}
	err_done=${jobs_dir_done}/${id}.${index}${extension_err}

	job=$(cat $job_main | head -n $index | tail -n 1)

	echo "$(date) - EXECUTING $id.$index on processor $processor ($job)"

	# reserve processor
	echo "$id.$index" > $processor_file

	# write job to running
	echo $job > $job_running

	# executing actual job
	echo "JOBS-start: $(date +%s%N) $(date)" > $log_running
	taskset -c $processor bash $job_running 1>> $log_running 2> $err_running
	echo "" >> $log_running
	echo "JOBS-end: $(date +%s%N) $(date)" >> $log_running

	# moving job and log file to done
	mv $job_running $job_done
	mv $log_running $log_done
	
	# moving err file to done (deleting it in case it is empty)
	mv $err_running $err_done
	if [[ $(cat $err_done | wc -l) -eq "0" ]]; then rm $err_done; fi

	# release processor
	echo "removing ${jobs_dir_processors}/${processor}"
	rm ${jobs_dir_processors}/${processor}

	echo "$(date) - DONE with job $id.$index"
	exit
fi





if [[ $1 = "start" ]]; then
	ssh $server_name "cd $server_dir; ./jobs.sh startServer"
	exit
fi

if [[ $1 = "startServer" ]]; then
	count=$(ls $jobs_dir_running | grep $extension_job | wc -l)
	echo "$(date) - $count jobs are RUNNING"
	count=$(ls $jobs_dir_new | grep $extension_job | wc -l)
	echo "$(date) - $count jobs are NEW"

	for job in $(ls -tr $jobs_dir_new | grep $extension_job); do
		count=$(ls $jobs_dir_running | grep $extension_job | wc -l)
		if [[ $count -ge $concurrent_jobs ]]; then
			echo "$(date) - already $count jobs running..."
			break
		fi
		processors_free=$((concurrent_jobs - count))
		processors_required=$(cat $jobs_dir_new/$job | wc -l)
		if [[ $processors_free -lt $processors_required ]]; then
			echo "$(date) - $processors_required processors for next job required, only $processors_free free"
			break
		fi
		id="${job%%.*}"

		echo "starting $id"
		echo "free: $((concurrent_jobs - count))"
		echo "required: $processors_required"

		./jobs.sh executeServer $id &

		sleep 1

		count=$(ls $jobs_dir_running | grep $extension_job | wc -l)
		echo "$(date) - now, $count jobs are RUNNING"
	done
	exit
fi




if [[ $1 = "help" ]] || [[ $1 = "--help" ]] || [[ $1 = "h" ]] || [[ $1 = "--h" ]]; then
	if [[ $2 = "deploy" ]] || [[ $2 = "create" ]] || [[ $2 = "bulkCreate" ]] || [[ $2 = "stash" ]] || [[ $2 = "unstash" ]] || [[ $2 = "archive" ]] || [[ $2 = "trash" ]] || [[ $2 = "start" ]] || [[ $2 = "execute" ]] || [[ $2 = "status" ]] || [[ $2 = "list" ]] || [[ $2 = "info" ]] || [[ $2 = "log" ]]; then
		echo "JOBS - usage of command '$2'"
	fi
	if   [[ $2 = "deploy" ]]; then
		echo "  jobs.sh deploy"
	elif [[ $2 = "create" ]]; then
		echo "  jobs.sh create \$task"
	elif [[ $2 = "bulkCreate" ]]; then
		echo "  jobs.sh bulkCreate \$file"
	elif [[ $2 = "stash" ]]; then
		echo "  jobs.sh stash"
	elif [[ $2 = "unstash" ]]; then
		echo "  jobs.sh unstash"
	elif [[ $2 = "archive" ]]; then
		echo "  jobs.sh archive"
	elif [[ $2 = "trash" ]]; then
		echo "  jobs.sh trash (new|done|archive|stashed)"
	elif [[ $2 = "start" ]]; then
		echo "  jobs.sh start"
	elif [[ $2 = "execute" ]]; then
		echo "  jobs.sh execute \$task_id"
	elif [[ $2 = "status" ]]; then
		echo "  jobs.sh status"
	elif [[ $2 = "list" ]]; then
		echo "  jobs.sh list \$type"
		echo "  jobs.sh list (new|running|done|done_err|archive|archive_err|stashed)"
	elif [[ $2 = "info" ]]; then
		echo "  jobs.sh list \$type"
		echo "  jobs.sh list (new|running|done|archive)"
	elif [[ $2 = "log" ]]; then
		echo "  jobs.sh log \$operation \$type \$file"
		echo "  jobs.sh log (cat|tail|tailf) (new|running|done|archive) (job|log|err)"
	else
		echo "> > > > > > > > > > > > > > > > > > > >"
		echo "> > > JOBS help"
		echo "> > > > > > > > > > > > > > > > > > > >"
		echo "> possible commands are:"
		echo ">   deployment:      deploy"
		echo ">   maintenance:     create, bulkCreate, stash, unstash, archive, trash"
		echo ">   starting jobs:   start, execute"
		echo ">   retrieving info: status, list, info, log"
		echo "> > > > > > > > > > > > > > > > > > > >"
		echo "> to show this help:       jobs.sh help"
		echo "> show help for a command: jobs.sh help \$command"
		echo "> executing a command:     jobs.sh \$command [\$parameters]"
		echo "> > > > > > > > > > > > > > > > > > > >"
	fi
	exit
fi




echo "Unknown command: '$1'"
echo "Type './jobs.sh help' for usage."
exit 1