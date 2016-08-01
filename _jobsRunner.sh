#!/bin/bash

while [[ true ]]; do
	date
	./jobs.sh startServer
	./jobs.sh statusServer
	sleep 10
done