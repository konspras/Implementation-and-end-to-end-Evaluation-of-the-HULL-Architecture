#!/bin/bash

# for 20% load: for: 0.09, back 200 (20% of requests are backg and 80% are fore)
# for 40% 0.18 400
# for 60% 0.27 600
file_names=''onlyfanout_wkld0_45_10flows' 'bkg200_fanout_wkld0_45_10flows' 'bkg400_fanout_wkld0_45_10flows' 'bkg600_fanout_wkld0_45_10flows''
indx=0


# General parameters
have_fanout='1'
loads='45'
workload_types='0'

have_bkg_list='0 1 1 1'
background_traffic_list='1 200 400 600'
have_frg='0'
foreground_traffic='0.09'
hv_bkg=($have_bkg_list)
bkg=($background_traffic_list)



# in Mbps
link_speed='1000'
# in ms
link_latency='0.005'
traffic_durations='27 27 27 27'
traf=($traffic_durations)
nums_flows='10'
q_size='500'

PQ_on='0'
PQ_rate='0.95'
PQ_thresh='1000.0'

pacer_bucket='24000.0'

for file_name in $file_names
do
	echo $file_name
	background_traffic=${bkg[$indx]}
	have_bkg=${hv_bkg[$indx]}
	traffic_duration=${traf[$indx]}


	echo "TCP-DROPTAIL"
	result_path="results/$file_name/TCP"
	mkdir -p $result_path

	PQ_on='0'
	DCTCP='0'
	pacer_on='0'

	ns simulation.tcl $result_path $loads $nums_flows $loads $workload_types \
		$DCTCP $link_speed $PQ_on $PQ_rate $PQ_thresh $q_size $pacer_on \
		$have_bkg $background_traffic $have_frg $foreground_traffic $have_fanout \
		$pacer_bucket $link_latency $traffic_duration &


	echo "DCTCP-30K"
	result_path="results/$file_name/DCTCP30"
	mkdir -p $result_path

	PQ_on='0'
	DCTCP='30'
	pacer_on='0'

	ns simulation.tcl $result_path $loads $nums_flows $loads $workload_types \
		$DCTCP $link_speed $PQ_on $PQ_rate $PQ_thresh $q_size $pacer_on \
		$have_bkg $background_traffic $have_frg $foreground_traffic $have_fanout \
		$pacer_bucket $link_latency $traffic_duration &


	echo "DCTCP_pacer_PQ_95_1000"
	result_path="results/$file_name/DCTCP_pacer_PQ"
	mkdir -p $result_path

	DCTCP='500'
	PQ_on='1'
	PQ_rate='0.95'
	PQ_thresh='1000.0'
	pacer_on='1'

	ns simulation.tcl $result_path $loads $nums_flows $loads $workload_types \
		$DCTCP $link_speed $PQ_on $PQ_rate $PQ_thresh $q_size $pacer_on \
		$have_bkg $background_traffic $have_frg $foreground_traffic $have_fanout \
		$pacer_bucket $link_latency $traffic_duration &

	let indx++
done

wait
