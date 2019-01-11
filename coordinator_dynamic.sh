#!/bin/bash

# for 20% load: for: 0.09, back 200 (20% of requests are backg and 80% are fore)
# for 40% 0.18 400
# for 60% 0.27 600
file_names=''nofanout_20_9flows' 'nofanout_40_9flows' 'nofanout_60_9flows''
indx=0


# General parameters
have_fanout='0'
loads='10'
workload_types='0'

have_bkg='1'
background_traffic_list='200 400 600'
have_frg='1'
foreground_traffic_list='0.09 0.18 0.27'
bkg=($background_traffic_list)
frg=($foreground_traffic_list)


# in Mbps
link_speed='1000'
# in ms
link_latency='0.005'
traffic_durations='750 380 250'
traf=($traffic_durations)
nums_flows='9'
q_size='500'

PQ_on='0'
PQ_rate='0.95'
PQ_thresh='1000.0'

pacer_bucket='24000.0'

for file_name in $file_names
do
	echo $file_name
	background_traffic=${bkg[$indx]}
	foreground_traffic=${frg[$indx]}
	traffic_duration=${traf[$indx]}


	echo "TCP-DROPTAIL"
	result_path="results/$file_name/TCP"
	mkdir -p $result_path

	PQ_on='0'
	DCTCP='0'
	pacer_on='0'

	ns simulation_final.tcl $result_path $loads $nums_flows $loads $workload_types \
		$DCTCP $link_speed $PQ_on $PQ_rate $PQ_thresh $q_size $pacer_on \
		$have_bkg $background_traffic $have_frg $foreground_traffic $have_fanout \
		$pacer_bucket $link_latency $traffic_duration
	echo "----------------------------------------------------------------------"


	echo "DCTCP-30K"
	result_path="results/$file_name/DCTCP30"
	mkdir -p $result_path

	PQ_on='0'
	DCTCP='32'
	pacer_on='0'

	ns simulation_final.tcl $result_path $loads $nums_flows $loads $workload_types \
		$DCTCP $link_speed $PQ_on $PQ_rate $PQ_thresh $q_size $pacer_on \
		$have_bkg $background_traffic $have_frg $foreground_traffic $have_fanout \
		$pacer_bucket $link_latency $traffic_duration
	echo "----------------------------------------------------------------------"


	echo "DCTCP-6K_pacer"
	result_path="results/$file_name/DCTCP6_pacer"
	mkdir -p $result_path

	PQ_on='0'
	DCTCP='6'
	pacer_on='1'

	ns simulation_final.tcl $result_path $loads $nums_flows $loads $workload_types \
		$DCTCP $link_speed $PQ_on $PQ_rate $PQ_thresh $q_size $pacer_on \
		$have_bkg $background_traffic $have_frg $foreground_traffic $have_fanout \
		$pacer_bucket $link_latency $traffic_duration
	echo "----------------------------------------------------------------------"


	echo "DCTCP_pacer_PQ_95_1000"
	result_path="results/$file_name/DCTCP_pacer_PQ"
	mkdir -p $result_path

	DCTCP='500'
	PQ_on='1'
	PQ_rate='0.95'
	PQ_thresh='1000.0'
	pacer_on='1'

	ns simulation_final.tcl $result_path $loads $nums_flows $loads $workload_types \
		$DCTCP $link_speed $PQ_on $PQ_rate $PQ_thresh $q_size $pacer_on \
		$have_bkg $background_traffic $have_frg $foreground_traffic $have_fanout \
		$pacer_bucket $link_latency $traffic_duration

	let indx++
done
