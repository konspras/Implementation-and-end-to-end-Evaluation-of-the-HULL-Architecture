#!/bin/bash

# result path ||| number of flows ||| DCTCP ||| link_speed ||| has_PQ ||| PQ_rate |||
# PQ_thresh ||| queue_size ||| has_pacer ||| label
nums_flows='2 3 4 5 6 7 8'
# nums_flows='4 5'
for num_flows in $nums_flows
do
	echo "Number of flows: $num_flows"
	ns static_flow_simulation.tcl results/static_flow $num_flows 0 1000 0 0.95 1000 500 0 TCP
	echo ---------------------------------------------------------------------------
	ns static_flow_simulation.tcl results/static_flow $num_flows 50 1000 0 0.95 1000 500 0 DCTCP
	echo ---------------------------------------------------------------------------
	ns static_flow_simulation.tcl results/static_flow $num_flows 10 1000 0 0.95 1000 500 1 DCTCP6_Pacer
	echo ---------------------------------------------------------------------------
	ns static_flow_simulation.tcl results/static_flow $num_flows 500 1000 1 0.9 1000 500 1 DCTCP_Pacer_PQ
	echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
done
echo "Simulations Completed"