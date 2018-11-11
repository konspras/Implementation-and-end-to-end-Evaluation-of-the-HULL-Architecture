#!/bin/bash
# This script will be used to run simulations and store the results in a way that
# fascilitates the creation of plots with the server load level in the x-axis

# Argument1 is configuration file, 2 is whether to run the simulations or work with
# existing data
# Variables: file_name, loads, nums_flows, workload_types

config_file=$1
run_simulations=$2

source $config_file

init_result_path="results/$file_name"
result_paths=''
num_of_paths=0


for workload_type in $workload_types
do
	echo workload_type: $workload_type
	for num_flows in $nums_flows
	do
		echo num_flows: $num_flows
		tmp_path="$init_result_path/workload$workload_type|flows$num_flows"
		mkdir -p $tmp_path
		result_paths="$result_paths $tmp_path"
		let num_of_paths++
		for load in $loads
		do
			echo Load: $load
			# args are: 1)path to store results, 2)the x-axis parameter (to identify
			# the output file), 3+) parameters
			if [ $run_simulations = 1 ]
			then
				ns simulation.tcl $tmp_path $load $num_flows $load $workload_type
			fi
		done
	done
done

# The data parsing script will assign the different load levels to the x-axis 
# (files within a folder) and will create at least one "line" for each parameter
# other than load (one for each folder in result_paths)
# Args: 1: number of folders with data(num of paths), 2: the name of the config file
# 3 to num_of_paths: paths, 
# next: x-axis name, rest: the x axis values (also used to id csv files in the folders)
echo Calling python script
python3 parse_data.py $file_name $num_of_paths $result_paths 'Server Load' $loads 

echo Simulations done