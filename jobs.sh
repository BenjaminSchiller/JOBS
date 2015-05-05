#!/bin/bash

source jobs.cfg

# set -e




if [[ $1 = "deploy" ]]; then
	echo "deploy to $server_name:$server_dir"
	ssh $server_name "if [[ ! -d $server_dir ]]; then mkdir $server_dir; fi; \
		if [[ ! -d $server_dir/$jobs_dir_new ]]; then mkdir $server_dir/$jobs_dir_new; fi; \
		if [[ ! -d $server_dir/$jobs_dir_running ]]; then mkdir $server_dir/$jobs_dir_running; fi; \
		if [[ ! -d $server_dir/$jobs_dir_done ]]; then mkdir $server_dir/$jobs_dir_done; fi; \
		if [[ ! -d $server_dir/$jobs_dir_archive ]]; then mkdir $server_dir/$jobs_dir_archive; fi"
	rsync -auvzl jobs.{cfg,sh} $server_name:$server_dir/
	echo "done"
	exit
fi




if [[ $1 = "status" ]]; then
	ssh $server_name "cd $server_dir; ./jobs.sh statusServer"
	exit
fi

if [[ $1 = "statusServer" ]]; then
	count_new=$(ls $jobs_dir_new | grep $extension_job | wc -l)
	count_running=$(ls $jobs_dir_running | grep $extension_job | wc -l)
	count_done=$(ls $jobs_dir_done | grep $extension_job | wc -l)
	count_done_failed=$(ls $jobs_dir_done | grep $extension_err | wc -l)
	count_archive=$(ls $jobs_dir_archive | grep $extension_job | wc -l)
	count_archive_failed=$(ls $jobs_dir_archive | grep $extension_err | wc -l)
	echo "new:     $count_new"
	echo "running: $count_running / $concurrent_jobs"
	echo "done:    $count_done ($count_done_failed)"
	echo "archive: $count_archive ($count_archive_failed)"
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
		ls $jobs_dir_new | grep $extension_job
	elif [[ $2 = "running" ]]; then
		ls $jobs_dir_running | grep $extension_job
	elif [[ $2 = "done" ]]; then
		ls $jobs_dir_done | grep $extension_job
	elif [[ $2 = "archive" ]]; then
		ls $jobs_dir_archive | grep $extension_job
	else
		echo "invalid job type '$2'"
		echo "  should be: new, running, done, archive"
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
	echo "${@:2}" > ${jobs_dir_new}/$id${extension_job}
	echo "created job '$id' --> ${@:2}"
	exit
fi







if [[ $1 = "trash" ]]; then
	ssh $server_name "cd $server_dir; ./jobs.sh trashServer"
	exit
fi

if [[ $1 = "trashServer" ]]; then
	count_jobs=$(ls $jobs_dir_new | wc -l)
	if [[ $count_jobs > 0 ]]; then
		rm $jobs_dir_new/*
		echo "trashed $count_jobs new jobs"
	else
		echo "no new jobs to trash"
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

	echo "$(date) - EXECUTING job $id ($(cat $job_new))" >> $main_log
	mv $job_new $job_running

	bash $job_running 1> $log_running 2> $err_running

	mv $job_running $job_done
	mv $log_running $log_done
	mv $err_running $err_done
	if [[ $(cat $err_done | wc -l) -eq "0" ]]; then rm $err_done; fi

	echo "$(date) - DONE with job $id" >> $main_log
	exit
fi





if [[ $1 = "start" ]]; then
	ssh $server_name "cd $server_dir; ./jobs.sh startServer"
	exit
fi

if [[ $1 = "startServer" ]]; then
	count=$(ls $jobs_dir_running | grep $extension_job | wc -l)
	echo "$(date) - $count jobs are RUNNING" >> $main_log
	count=$(ls $jobs_dir_new | grep $extension_job | wc -l)
	echo "$(date) - $count jobs are NEW" >> $main_log

	for job in $(ls -tr $jobs_dir_new | grep $extension_job); do
		count=$(ls $jobs_dir_running | grep $extension_job | wc -l)
		if [[ $count -ge $concurrent_jobs ]]; then
			echo "$(date) - already $count jobs running..." >> $main_log
			break
		fi
		id="${job%%.*}"
		./jobs.sh executeServer $id >> $main_log &

		sleep 1

		count=$(ls $jobs_dir_running | grep $extension_job | wc -l)
		echo "$(date) - now, $count jobs are RUNNING" >> $main_log
	done
	exit
fi





echo "no operation specified"
exit 1