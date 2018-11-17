#!/bin/bash
# This script will be used to run simulations and store the results in a way that
# fascilitates the creation of plots.

# Argument1 is configuration file, 2 is whether to run the simulations or work with
# appropriate existing data

config_file=$1
run_simulations=$2

source $config_file

init_result_path="results/$file_name"
result_paths=''
num_of_paths=0
for y6 in $y_axis6
do
	echo $y_axis6_name $y6
	for y5 in $y_axis5
	do
		echo $y_axis5_name $y5
		for y4 in $y_axis4
		do
			echo $y_axis4_name $y4
			for y3 in $y_axis3
			do
				echo $y_axis3_name $y3
				for y2 in $y_axis2
				do
					echo $y_axis2_name: $y2
					for y1 in $y_axis1
					do
						echo $y_axis1_name: $y1
						tmp_path="$init_result_path/$y_axis6_name$y6|$y_axis5_name$y5|$y_axis4_name$y4|$y_axis3_name$y3|$y_axis2_name$y2|$y_axis1_name$y1"
						mkdir -p $tmp_path
						result_paths="$result_paths $tmp_path"
						let num_of_paths++
						for x in $x_axis
						do
							echo $x_axis_name: $x
							# args are: 1)path to store results, 2)the x-axis parameter (to identify
							# the output file), 3+) parameters
							if [ $run_simulations = 1 ]
							then
								#wthis is sketchy..
								source $config_file
								echo $sim_cmnd
								$sim_cmnd
							fi
						done
					done
				done
			done
		done
	done
done
# The data parsing script will assign the different x_axis levels to the x-axis 
# (files within a folder) and will create at least one "plot-line" for each parameter
# other than the x_axis (one for each folder in result_paths)
# Args: 1: number of folders with data(num of paths), 2: the name of the config file
# 3 to num_of_paths: paths, 
# next: x-axis name, rest: the x axis values (also used to id csv files in the folders)
echo Calling python script
python3 parse_data.py $file_name $num_of_paths $result_paths $x_axis_name $x_axis 

echo Simulations done