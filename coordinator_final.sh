#file_name='nofanout_60_9flows'
#file_name='onlyfanout_wkld1_30_10flows'
#file_name='onlyfanout_wkld1_30_10flows_4000tokens'
#file_name='bkg200_fanout_wkld1_30_10flows'
# file_name='bkg200_fanout_wkld4_30_10flows'
#file_name='bkg200_fanout_wkld4_30_10flows_4000tokens'
#file_name='bkg400_fanout_wkld1_30_10flows'
file_name='bkg600_fanout_wkld1_30_10flows'
# file_name='bkg200_fanout_wkld4_30_10flows'
# for 20% load: for: 0.09, back 200 (20% of requests are backg and 80% are fore)
# for 40% 0.18 400
# for 60% 0.27 600

# General parameters
have_fanout='1'
loads='30'
workload_types='1'
have_bkg='1'
background_traffic='600'
have_frg='0'
foreground_traffic='0.27'

link_speed='1000'
nums_flows='10'
q_size='500'

PQ_on='0'
PQ_rate='0.95'
PQ_thresh='1000.0'

pacer_bucket='24000.0'


# TCP-DROPTAIL
result_path="results/$file_name/TCP"
mkdir -p $result_path

DCTCP='0'
pacer_on='0'

ns simulation.tcl $result_path $loads $nums_flows $loads $workload_types \
	$DCTCP $link_speed $PQ_on $PQ_rate $PQ_thresh $q_size $pacer_on \
	$have_bkg $background_traffic $have_frg $foreground_traffic $have_fanout \
	$pacer_bucket
echo "----------------------------------------------------------------------"


# DCTCP-30K
result_path="results/$file_name/DCTCP30"
mkdir -p $result_path

DCTCP='32'
pacer_on='0'

ns simulation.tcl $result_path $loads $nums_flows $loads $workload_types \
	$DCTCP $link_speed $PQ_on $PQ_rate $PQ_thresh $q_size $pacer_on \
	$have_bkg $background_traffic $have_frg $foreground_traffic $have_fanout \
	$pacer_bucket
echo "----------------------------------------------------------------------"


# # DCTCP-6K_pacer
# result_path="results/$file_name/DCTCP6_pacer"
# mkdir -p $result_path

# DCTCP='6'
# pacer_on='1'

# ns simulation.tcl $result_path $loads $nums_flows $loads $workload_types \
# 	$DCTCP $link_speed $PQ_on $PQ_rate $PQ_thresh $q_size $pacer_on \
# 	$have_bkg $background_traffic $have_frg $foreground_traffic $have_fanout \
	# $pacer_bucket
# echo "----------------------------------------------------------------------"


# DCTCP_pacer_PQ_95_1000
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
	$pacer_bucket