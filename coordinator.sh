#!/bin/bash

source configuration.txt

for load in $loads
do
	echo LOAD IS $load
	ns simulation.tcl $num_flows $load $workload_type
done

echo Simulations done