#!/bin/bash

# result path ||| number of flows ||| DCTCP ||| link_speed ||| has_PQ ||| PQ_rate |||
# PQ_thresh ||| queue_size ||| has_pacer ||| label
nums_flows='2 3 4 5 6 7 8'
link_speed='1000'
link_latency='0.1'
path='results/static_flow_100'
for num_flows in $nums_flows
do
	echo "Number of flows: $num_flows"
	ns static_flow_simulation.tcl $path $num_flows 0 $link_speed 0 0.95 1000 500 0 $link_latency TCP
	echo ---------------------------------------------------------------------------
	ns static_flow_simulation.tcl $path $num_flows 32 $link_speed 0 0.95 1000 500 0 $link_latency DCTCP
	echo ---------------------------------------------------------------------------
	ns static_flow_simulation.tcl $path $num_flows 6 $link_speed 0 0.95 1000 500 1 $link_latency DCTCP6_Pacer
	echo ---------------------------------------------------------------------------
	ns static_flow_simulation.tcl $path $num_flows 500 $link_speed 1 0.9 1000 500 1 $link_latency DCTCP_Pacer_PQ
	echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
done
echo "Simulations Completed"