source "util.tcl"

set result_path [lindex $argv 0]
# used to identify the output files
set file_ident [lindex $argv 1]
set num_flows [lindex $argv 2]
# server load in %
set server_load [lindex $argv 3]
set workload_type [lindex $argv 4]
set DCTCP [lindex $argv 5]
# in Mbps
set link_speed [lindex $argv 6]Mb
set has_PQ [lindex $argv 7]
set PQ_rate [lindex $argv 8]
set PQ_thresh [lindex $argv 9]
set queue_size [lindex $argv 10]
set has_pacer [lindex $argv 11]
# specify the desired mean load on the client-switch link.
# At poisson intervals, each server in a round robin fashiom will decide to start 
# sending a 10MB file to the client. To get the specified mean throughput, 
# the formula should be: 
# mean_send_interval = 80*10^6 / desired_thrpt 
set have_bkg_traffic [lindex $argv 12]
set background_traffic_mbbps [lindex $argv 13]
set have_frg_traffic [lindex $argv 14]
set foreground_traffic_mbbps [lindex $argv 15]
set have_fanout_traffic [lindex $argv 16]

# in bits (as hw impl of HULL) - 24000
set pacer_bucket_ [lindex $argv 17]
set link_latency [lindex $argv 18]ms
set traffic_duration [lindex $argv 19]
# not sure in what (bits/s)
set pacer_rate 100.0M
#set pacer_rate [expr $link_speed + 50 ]
# in pkts
set pacer_qlen $queue_size

# in ms - 5micro
#set link_latency 0.005ms

set DCTCP_g  [expr 1.0/16.0]

set simulation_duration [expr 100.0 + $traffic_duration]
set traffic_start_time 1.0
set background_traffic_duration $traffic_duration
set foreground_traffic_duration $traffic_duration
set fanout_traffic_duration $traffic_duration
# in packets
Queue set limit_ $queue_size
Queue/DropTail set drop_prio_ false
Queue/DropTail set deque_prio_ false

# Only let DCTCP handle ecn when there are no PQs (as in "Less is More")
if {$has_PQ == 0} {
    Queue/RED set setbit_ true
} else {
    Queue/RED set setbit_ false
}
# Defaults
# Queue/RED set bytes_ true
# Queue/RED set queue_in_bytes_ true
# with mean pkt size 1000, by setting the threshold to 30 we get 30KB
Queue/RED set mean_pktsize_ 1000
Queue/RED set gentle_ false
Queue/RED set q_weight_ 1.0
Queue/RED set mark_p_ 1.0
# in packets (def size is 500B)
Queue/RED set thresh_ $DCTCP
Queue/RED set maxthresh_ $DCTCP
Queue/RED set drop_prio_ false
Queue/RED set deque_prio_ false

file mkdir "log/$result_path"
set log_fp [open "log/$result_path/$file_ident|log" w]

set num_workloads [string length $workload_type]
for {set i 0} {$i < $num_workloads} {incr i} {
    set wk_type($i) [string index $workload_type $i]
    set wk_server_load($i) [string range $server_load [expr 2 * $i] [expr 2 * $i + 1]]
    if {$wk_type($i) == 0} {
        set req_size($i) 100
        set resp_size($i) 100
        set mean_service_time_s($i) 0.0001
    } elseif {$wk_type($i) == 1} {
        set req_size($i) 3500
        set resp_size($i) 2800
        set mean_service_time_s($i) 0.00253
    } elseif {$wk_type($i) == 2} {
        set req_size($i) 100
        set resp_size($i) 100
        set mean_service_time_s($i) 0.00253
    } elseif {$wk_type($i) == 3} {
        set req_size($i) 3500
        set resp_size($i) 2800
        set mean_service_time_s($i) 0.0001
    } elseif {$wk_type($i) == 4} {
        set req_size($i) 3500
        set resp_size($i) 2800
        set mean_service_time_s($i) 0.00253
    } elseif {$wk_type($i) == 5} {
        set req_size($i) 100
        # 1Mb
        set resp_size($i) 1000000 
        # 10ms
        set mean_service_time_s($i) 0.01
    } elseif {$wk_type($i) == 6} {
        set req_size($i) 100
        set resp_size($i) 100
        set mean_service_time_s($i) 0.0001
    # USR workload
    } elseif {$wk_type($i) == 7} {
        set req_size($i) 20
        set resp_size($i) 2
        set mean_service_time_s($i) 0.00001
    } else {
        set req_size($i) 3500
        set resp_size($i) 2800
        set mean_service_time_s($i) 0.00253
    }
    set exp_distr_mean($i) [expr [expr 1.0/[expr $wk_server_load($i)/100.0]] \
                        *$mean_service_time_s($i)]
    if {$have_fanout_traffic} {
        set pace [expr  8 * $resp_size($i) / $exp_distr_mean($i) / 1000000.0]
        set pkts_per_req [expr ceil( $req_size($i) / 950.0 )]
        set pkts_to_be_sent [expr 1 / $exp_distr_mean($i) * $fanout_traffic_duration * $pkts_per_req]
        puts "Packets expected to be sent per flow by fanout workload $wk_type($i) = $pkts_to_be_sent"
        puts "Mean pace of fanout workload $wk_type($i) = $pace (Mbps)"
        puts "Mean total traffic of fanout workload $wk_type($i) = [expr $num_flows*$pace] (Mbps)"
        puts $log_fp "Packets expected to be sent per flow by fanout workload $wk_type($i) = $pkts_to_be_sent"
        puts $log_fp "Mean pace of fanout workload $wk_type($i) = $pace (Mbps)"
        puts $log_fp "Mean total traffic of fanout workload $wk_type($i) = [expr $num_flows*$pace] (Mbps)"
    }
}


proc monitor_progress {} {
    global ns simulation_duration num_flows tcp_bkg log_fp
    set time [$ns now]
    
    puts ">>Simulation is at second $time out of $simulation_duration"
    puts $log_fp "Simulation is at second $time out of $simulation_duration"
    $ns at [expr $time + 5.0] monitor_progress
}
#Define a 'finish' procedure
proc finish {} {
    global ns nf tf qf tchan_ tcp_ll num_flows sendTimesList receiveTimesList result_path \
            file_ident DCTCP num_workloads wk_type bkg_send_times bkg_recv_times \
            frg_send_times frg_recv_times background_traffic_mbbps foreground_traffic_mbbps \
            have_fanout_traffic have_bkg_traffic have_frg_traffic cl_reqs_recv serv_reqs_rcved \
            bkg_request_id fr_cl_reqs_recv fr_serv_reqs_rcved frg_request_id log_fp
    # puts "BKG: REQS scheduled: $bkg_request_id || SERVER REQS RECVD: $serv_reqs_rcved || CL REQS RECV: $cl_reqs_recv"
    # puts "FRG: REQS scheduled: $frg_request_id || SERVER REQS RECVD: $fr_serv_reqs_rcved || CL REQS RECV: $fr_cl_reqs_recv"
    if {$have_fanout_traffic} {
        dispRes $num_flows $num_workloads $sendTimesList $receiveTimesList $log_fp
        for {set wkld 0} {$wkld < $num_workloads} {incr wkld} {
            set send_lst [lindex $sendTimesList $wkld]
            set recv_lst [lindex $receiveTimesList $wkld]
            saveListToFile $result_path "fanout" $send_lst $recv_lst $num_flows
        }
    }
    if {$have_frg_traffic} {
        saveArrayToFile $result_path "foreground" \
                        frg_send_times frg_recv_times
    }
    if {$have_bkg_traffic} {
        saveArrayToFile $result_path "background" \
                        bkg_send_times bkg_recv_times
    }
    
    $ns flush-trace
    #Close the NAM trace file
    #close $nf
    # close $tf
    # if {$DCTCP != 0} {
    #     close $tchan_
    # }
    close $qf
    close $log_fp
    #Execute NAM on the trace file
    #exec nam out.nam &
    exit 0
}


set ns [new Simulator]
# set tf [open out.tr w]
# $ns trace-all $tf

# set nf [open out.nam w]
# $ns namtrace-all $nf

# ------------------------------Nodes--------------------------------------
set switch_node [$ns node]
set client_node [$ns node]
for {set i 0} {$i < $num_flows} {incr i} {
    set s($i) [$ns node]
}

set host_queue_type DropTail
if {$DCTCP != 0} {
    set sw_queue_type RED
} else {
    set sw_queue_type DropTail
}
# Connect Nodes
# CLIENT
$ns simplex-link $switch_node $client_node $link_speed $link_latency $sw_queue_type
$ns simplex-link $client_node $switch_node $link_speed $link_latency $host_queue_type
# probly in packets
$ns queue-limit $client_node $switch_node 1000

if {$has_PQ} {
    $ns simplex-link-op $switch_node $client_node phantomQueue $PQ_rate $PQ_thresh
}

if {$has_pacer} {
    set client_pacer [new HullPacer]
    $client_pacer set bucket_ $pacer_bucket_
    $client_pacer set rate_ $pacer_rate
    $client_pacer set qlen_  $pacer_qlen
    $client_pacer set rate_upd_interval_  0.000032
    $client_pacer set verbose_ 0
    $client_pacer set num_flows_ [expr 2*$num_flows]

    $ns simplex-link-op $client_node $switch_node insert-hullPacer $client_pacer
}

# SERVERS
for {set i 0} {$i < $num_flows} {incr i} {
    $ns simplex-link $switch_node $s($i) $link_speed $link_latency $sw_queue_type
    $ns simplex-link $s($i) $switch_node $link_speed $link_latency $host_queue_type
    $ns queue-limit $s($i) $switch_node 1000

    if {$has_PQ} {
        $ns simplex-link-op $switch_node $s($i) phantomQueue $PQ_rate $PQ_thresh
    }

    if {$has_pacer} {
        set server_pacer($i) [new HullPacer]
        $server_pacer($i) set bucket_ $pacer_bucket_
        $server_pacer($i) set rate_ $pacer_rate
        $server_pacer($i) set qlen_  $pacer_qlen
        $server_pacer($i) set rate_upd_interval_  0.000032
        if {$i == 0} {
            $server_pacer($i) set verbose_ 0
            $server_pacer($i) set num_flows_ [expr 2*$num_flows]
        }
        $ns simplex-link-op $s($i) $switch_node insert-hullPacer $server_pacer($i)
    }
}

# ------------------------------Agents-----------------------------------------

#Monitor the queue for link (s1-h3). (for NAM)
#$ns duplex-link-op $switch_node $dst_node queuePos 0.5

# These vars don't seem to exist anywhere...
# if {[string compare $sourceAlg "DC-TCP-Sack"] == 0} {
#     Agent/TCP set dctcp_ true
#     Agent/TCP set dctcp_g_ $DCTCP_g_;
# }

# CONFIG : https://github.com/camsas/qjump-ns2/blob/master/qjump.tcl
# def is 1000
#Agent/TCP set packetSize_ $packetSize
# def is 536 - example uses 1460.. but the PQ threshold!
#Agent/TCP/FullTcp set segsize_ $packetSize
# default is 20! ex is at 1256, repr is at infin. was not using this until 18/11
# Book sais Upper bound on window size
Agent/TCP set window_ 1256
Agent/TCP set max_ssthresh_ 111200
Agent/TCP set minrto_ 0.01
# boolean: re-init cwnd after connection goes idle.  On by default. 
# used true from reproduc until 18/11. Setting to false bcs of example
Agent/TCP set slow_start_restart_ false
# def is 1. Not clear what it is. dctcp example has it at 0
Agent/TCP set windowOption_ 0
# probly smthing to do with simulation sampling. extreme (0.000001 <- dctcp
# reproductions study (was using until 19/11)) - 0.01 is default and also used in example. 
Agent/TCP set tcpTick_ 0.00000001
# retransmission time out. default values are fine.
#Agent/TCP set minrto_ $min_rto
#Agent/TCP set maxrto_ 2

# Don't know what this is. default is 0
# "below do 1 seg per ack [0:disable]"
Agent/TCP/FullTcp set spa_thresh_ 0
# disable sender-side Nagle? def: false
# https://www.lifewire.com/nagle-algorithm-for-tcp-network-communication-817932
Agent/TCP/FullTcp set nodelay_ true; # disable Nagle
# def is 1. "ACK frequency". (there is a segs_per_ack_ in .h)
Agent/TCP/FullTcp set segsperack_ 1;
# delayed ack (repr has it at 0.000006, ex has it at 0.04, def is 0.1)
Agent/TCP/FullTcp set interval_ 0.000006
# set at 600 bcs not sure of how a 1KB PQ threshold is supposed to work with 1500B
# packets. DCTCP K is in packets. So to get 30K need to set it to 30,000/950 = 32
Agent/TCP/FullTcp set segsize_ 950

if {$DCTCP != 0} {
    # def is 0
    Agent/TCP set ecn_ 1
    # def is 0
    Agent/TCP set old_ecn_ 1
    Agent/TCP set ecnhat_ true
    Agent/TCPSink set ecnhat_ true
    Agent/TCP set ecnhat_g_ $DCTCP_g;
}

# select if standard TCP ECN cabable
# if {$has_PQ} {
#     Agent/TCP set ecn_ 1
#     Agent/TCP set old_ecn_ 1
# }

# Set FANOUT Agents. One flow per application per server. List of lists (ll). frst define
# workload indx and then flow
#       flow
# wkld|   |   | ...
#     |   |   | ...
#       ...

set flow_id 0
set tcp_ll {}
set sink_ll {}
set app_client_ll {}
set app_server_ll {}
for {set wkld 0} {$wkld < $num_workloads} {incr wkld} {
    for {set i 0} {$i < $num_flows} {incr i} {
        # .... 
        if {$wkld > 0} {
            set cur_tcp_lst [lindex $tcp_ll $i]
            set tcp_ll [lreplace $tcp_ll $i $i [lappend cur_tcp_lst [new Agent/TCP/FullTcp]]]
        } else {
            lappend tcp_ll [new Agent/TCP/FullTcp]
        }
        
        #set tcp($i) [new Agent/TCP/FullTcp]
        if {$wkld > 0} {
            set cur_sink_lst [lindex $sink_ll $i]
            set sink_ll [lreplace $sink_ll $i $i [lappend cur_sink_lst [new Agent/TCP/FullTcp]]]
        } else {
            lappend sink_ll [new Agent/TCP/FullTcp]
        }
        
        #set sink($i) [new Agent/TCP/FullTcp]
        $ns attach-agent $client_node [lindex [lindex $tcp_ll $i] $wkld]
        #$ns attach-agent $client_node $tcp($i)
        $ns attach-agent $s($i) [lindex [lindex $sink_ll $i] $wkld]
        #$ns attach-agent $s($i) $sink($i)
        [lindex [lindex $tcp_ll $i] $wkld] set fid_ $flow_id
        #$tcp($i) set fid_ [expr $i]
        [lindex [lindex $sink_ll $i] $wkld] set fid_ $flow_id
        #$sink($i) set fid_ [expr $i]
        incr flow_id
        $ns connect [lindex [lindex $tcp_ll $i] $wkld] [lindex [lindex $sink_ll $i] $wkld]
        #$ns connect $tcp($i) $sink($i)
        [lindex [lindex $sink_ll $i] $wkld] listen
        #$sink($i) listen

        # Set client application
        if {$wkld > 0} {
            set cur_cl_app_lst [lindex $app_client_ll $i]
            set app_client_ll [lreplace $app_client_ll $i $i [lappend cur_cl_app_lst [new Application/TcpApp [lindex [lindex $tcp_ll $i] $wkld]]]]    
        } else {
            lappend app_client_ll [new Application/TcpApp [lindex [lindex $tcp_ll $i] $wkld]]
        }
        #set app_client($i) [new Application/TcpApp $tcp($i)]
        # Set server application
        if {$wkld > 0} {
            set cur_sv_app_lst [lindex $app_server_ll $i]
            set app_server_ll [lreplace $app_server_ll $i $i [lappend cur_sv_app_lst [new Application/TcpApp [lindex [lindex $sink_ll $i] $wkld]]]]    
        } else {
            lappend app_server_ll [new Application/TcpApp [lindex [lindex $sink_ll $i] $wkld]]
        }
        # set app_server($i) [new Application/TcpApp $sink($i)] 
        # Connect them
        [lindex [lindex $app_client_ll $i] $wkld] connect [lindex [lindex $app_server_ll $i] $wkld]
        #$app_client($i) connect $app_server($i)
    }
}

# Set background and foreground agents
for {set i 0} {$i < $num_flows} {incr i} {
    set tcp_bkg($i) [new Agent/TCP/FullTcp]
    set tcp_frg($i) [new Agent/TCP/FullTcp]

    set sink_bkg($i) [new Agent/TCP/FullTcp]
    set sink_frg($i) [new Agent/TCP/FullTcp]

    $ns attach-agent $client_node $tcp_bkg($i)
    $ns attach-agent $client_node $tcp_frg($i)

    $ns attach-agent $s($i) $sink_bkg($i)
    $ns attach-agent $s($i) $sink_frg($i)

    $tcp_bkg($i) set fid_ $flow_id
    $sink_bkg($i) set fid_ $flow_id
    incr flow_id
    $tcp_frg($i) set fid_ $flow_id
    $sink_frg($i) set fid_ $flow_id
    incr flow_id

    $ns connect $tcp_bkg($i) $sink_bkg($i)
    $ns connect $tcp_frg($i) $sink_frg($i)

    $sink_bkg($i) listen
    $sink_frg($i) listen

    set app_client_bkg($i) [new Application/TcpApp $tcp_bkg($i)]
    set app_client_frg($i) [new Application/TcpApp $tcp_frg($i)]

    set app_server_bkg($i) [new Application/TcpApp $sink_bkg($i)] 
    set app_server_frg($i) [new Application/TcpApp $sink_frg($i)] 

    $app_client_bkg($i) connect $app_server_bkg($i)
    $app_client_frg($i) connect $app_server_frg($i)
}

# queue monitoring
set qf [open "$result_path/q_mon" w]
set qmon_size [$ns monitor-queue $switch_node $client_node $qf 0.01]
[$ns link $switch_node $client_node] queue-sample-timeout

# if {$DCTCP != 0} {
#     set cl_sw_q [[$ns link $switch_node $client_node] queue]
#     set tchan_ [open "$result_path/trace_q_$file_ident" w]
#     $cl_sw_q trace curq_
#     #$cl_sw_q trace ave_
#     $cl_sw_q attach $tchan_
# }

# ------------- Network Setup Complete - Proceed with sending queries ----------
# --------------------------------------------------------------------------------

# list of list of list. First indx is workload_type, 2nd indx is flow_id(server_id), 3d indx is time
# Holds, for each server, the timestamps of query sending and receiving times
set sendTimesList []
set receiveTimesList []
# For each server, the time until it is busy processing a query.
set busy_until []


 
# Initialize lists.. must find better way...
proc initialize_lists {} {
    global sendTimesList receiveTimesList busy_until num_flows num_workloads
    for {set wrkld 0} {$wrkld < $num_workloads} {incr wrkld} {
        set tmp_send {}
        set tmp_recv {}
        for {set i 0} {$i < $num_flows} {incr i} {
            lappend tmp_send 0.0
            lappend tmp_recv 0.0
            if {$wrkld == 0} {
                lappend busy_until 0.0
            }
        }
        lappend sendTimesList $tmp_send
        lappend receiveTimesList $tmp_recv
    }
}

initialize_lists
#puts $sendTimesList
# 2 workloads 10 flows each
# {0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0} {0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0} 
#puts $receiveTimesList
#puts $busy_until

# Loop over all workloads...
if {$have_fanout_traffic} {
    for {set wkld 0} {$wkld < $num_workloads} {incr wkld} {
        set send_interval [new RandomVariable/Exponential]
        set gamma_var($wkld) [new RandomVariable/Gamma]
        # Interval depends on desired load. For load 1, a query is sent at an interval
        # equal to the servers mean service time.
        $send_interval set avg_ $exp_distr_mean($wkld)
        if {$wk_type($wkld) == 6 } {
            $gamma_var($wkld) set alpha_ 0.7
            $gamma_var($wkld) set beta_ 790
        } else {
            $gamma_var($wkld) set alpha_ 0.7
            $gamma_var($wkld) set beta_ 20000
        }

        # Send requests for $simulation duration time
        set query_id 0
        set nextQueryTime [expr [$send_interval value] + $traffic_start_time]
        set traffic_end_time [expr $traffic_start_time + $fanout_traffic_duration]
        while {$nextQueryTime < $traffic_end_time} {
            #puts "nextQueryTime is $nextQueryTime"
            #puts "sendTimesList is: $sendTimesList"
            for {set i 0} {$i < $num_flows} {incr i} {
                set cur_app_client [lindex [lindex $app_client_ll $i] $wkld]
                set cur_app_server [lindex [lindex $app_server_ll $i] $wkld]
                $ns at $nextQueryTime "$cur_app_client send $req_size($wkld) {$cur_app_server \
                                        server-recv $req_size($wkld) $i $query_id $wk_type($wkld) $wkld}"
                
                #$ns at $nextQueryTime "$app_client($i) send $req_size {$app_server($i) \
                #                        server-recv $req_size $i $query_id}"
                #Register sending time for the client apps
                set cur_wk_ll [lindex $sendTimesList $wkld]
                set curSendList [lindex $cur_wk_ll $i]
                #set newSendList [lappend curSendList $nextQueryTime]
                set cur_wk_ll [lreplace $cur_wk_ll $i $i [lappend curSendList $nextQueryTime]]
                set sendTimesList [lreplace $sendTimesList $wkld $wkld $cur_wk_ll]
                #set sendTimesList [lreplace $sendTimesList $i $i [lappend curSendList $nextQueryTime]]
                
                # set sendTimesList [lreplace $sendTimesList $i $i \
                #                      [lappend [lindex $sendTimesList $i] $nextQueryTime]]
            }
            set nextQueryTime [expr $nextQueryTime + [$send_interval value]]
            incr query_id
        }
    }
puts "Fanout traffic scheduled"
}

# Initiate the background and foreground traffic ------------------------------------------
if {$have_bkg_traffic} {
    # background 10MB files = 80*10^6 bits
    set bkg_exp_distr_mean [expr 80.0 / $background_traffic_mbbps]
    puts "The client will request one 10MB file per $bkg_exp_distr_mean sec"
    set bkg_send_interval [new RandomVariable/Exponential]
    # Interval depends on desired load. 
    $bkg_send_interval set avg_ $bkg_exp_distr_mean
    set bkg_request_id 0
    set nextBkgRequestTime [expr [$bkg_send_interval value] + $traffic_start_time]
    set bkg_traffic_end_time [expr $traffic_start_time + $background_traffic_duration]
    while {$nextBkgRequestTime < $bkg_traffic_end_time} {
        for {set i 0} {$i < $num_flows} {incr i} {
            set cur_bkg_app_client $app_client_bkg($i)
            set cur_bkg_app_server $app_server_bkg($i)
            if {$nextBkgRequestTime < $bkg_traffic_end_time} {
                set bkg_send_times($bkg_request_id) $nextBkgRequestTime
                # puts "scheduling request $bkg_request_id for $nextBkgRequestTime"
                $ns at $nextBkgRequestTime "$cur_bkg_app_client send 100 {$cur_bkg_app_server \
                                            bkg-server-recv 100 $i $bkg_request_id }"
            }
            set nextBkgRequestTime [expr $nextBkgRequestTime + [$bkg_send_interval value]]
            incr bkg_request_id
        }
    }
puts "Background traffic scheduled"  
}

if {$have_frg_traffic} {
    # foreground 900 byte files = 7200 bits
    set frg_exp_distr_mean [expr 7200.0 / [expr $foreground_traffic_mbbps * 1000000.0]]
    puts "The client will request one 900B file per $frg_exp_distr_mean sec"
    set frg_send_interval [new RandomVariable/Exponential]
    $frg_send_interval set avg_ $frg_exp_distr_mean
    set frg_request_id 0
    set nextFrgRequestTime [expr [$frg_send_interval value] + $traffic_start_time]
    set frg_traffic_end_time [expr $traffic_start_time + $foreground_traffic_duration]
    while {$nextFrgRequestTime < $frg_traffic_end_time} {
        for {set i 0} {$i < $num_flows} {incr i} {
            set cur_frg_app_client $app_client_frg($i)
            set cur_frg_app_server $app_server_frg($i)
            if {$nextFrgRequestTime < $frg_traffic_end_time} {
                set frg_send_times($frg_request_id) $nextFrgRequestTime
                $ns at $nextFrgRequestTime "$cur_frg_app_client send 100 {$cur_frg_app_server \
                                            frg-server-recv 100 $i $frg_request_id }"
            }
            set nextFrgRequestTime [expr $nextFrgRequestTime + [$frg_send_interval value]]
            incr frg_request_id
        }
    }
puts "Foreground traffic scheduled"  

}

set cl_reqs_recv 0
set serv_reqs_rcved 0
set fr_cl_reqs_recv 0
set fr_serv_reqs_rcved 0

# ----------------------- Request sending times set -----------------------
# ----------------------------- Handle them -------------------------------
array set bkg_recv_times {}
Application/TcpApp instproc bkg-client-recv { size server_id request_id } {
        global ns bkg_recv_times cl_reqs_recv
        # puts ">>>>$request_id $server_id"
        set bkg_recv_times($request_id) [$ns now]   
        incr cl_reqs_recv
}

array set frg_recv_times {}
Application/TcpApp instproc frg-client-recv { size server_id request_id } {
        global ns frg_recv_times fr_cl_reqs_recv
        
        set frg_recv_times($request_id) [$ns now]
        incr fr_cl_reqs_recv
}

Application/TcpApp instproc client-recv { size server_id query_id wkld_indx} {
        global ns app_server app_client sendTimesList receiveTimesList send_interval \
                 tcp
        #puts "[$ns now] CLIENT received $size bytes response for query $query_id from server \
                        $server_id"
        # Register response arrival time
        set cur_wk_ll [lindex $receiveTimesList $wkld_indx]
        set curRecList [lindex $cur_wk_ll $server_id]
        #set newRecList [lappend curRecList [$ns now]]
        set cur_wk_ll [lreplace $cur_wk_ll $server_id $server_id [lappend curRecList [$ns now]]]
        set receiveTimesList [lreplace $receiveTimesList $wkld_indx \
                                        $wkld_indx $cur_wk_ll]
        # set receiveTimesList [lreplace $receiveTimesList $server_id $server_id \
        #                                  [lappend \
        #                                  [lindex $receiveTimesList $server_id] \
        #                                  [$ns now]]]
        #puts "STATUS: cwnd: [$tcp($server_id) set cwnd_]"
        #puts "================================================================"
}

Application/TcpApp instproc bkg-server-recv { size server_id request_id } {
        global ns app_client_bkg app_server_bkg serv_reqs_rcved
        incr serv_reqs_rcved
        # puts ">>Server $server_id received request $request_id"
        # Respond when the query has been processed
        set cur_time [$ns now]
        # 10MB
        set resp_size [expr 10.0 * 1000.0 * 1000.0]
        set cur_app_client $app_client_bkg($server_id)
        set cur_app_server $app_server_bkg($server_id)
        $ns at $cur_time "$cur_app_server send $resp_size \
                {$cur_app_client bkg-client-recv $resp_size $server_id $request_id}"
}

Application/TcpApp instproc frg-server-recv { size server_id request_id } {
        global ns app_client_frg app_server_frg fr_serv_reqs_rcved
        incr fr_serv_reqs_rcved
        # Respond when the query has been processed
        set cur_time [$ns now]
        # 900B
        set resp_size 900
        set cur_app_client $app_client_frg($server_id)
        set cur_app_server $app_server_frg($server_id)
        $ns at $cur_time "$cur_app_server send $resp_size \
                {$cur_app_client frg-client-recv $resp_size $server_id $request_id}"
}

Application/TcpApp instproc server-recv { size server_id query_id wkld_id wkld_indx} {
        global ns app_server app_client sendTimesList receiveTimesList \
                 busy_until gamma_var resp_size sink workload_type \
                 mean_service_time_s app_client_ll app_server_ll

        #puts "[$ns now] SERVER $server_id receives $size bytes query $query_id from client. \
                        Server is busy until [lindex $busy_until $server_id]"
        set cur_time [$ns now]
        set occupied_until [lindex $busy_until $server_id]

        if {$cur_time > $occupied_until} {
                set process_this_query_at $cur_time
                #puts "Processing right away"
        } else {
                set process_this_query_at $occupied_until
                #puts "currently busy"
        }
        if {$wkld_id == 0 || $wkld_id == 3 || $wkld_id == 4 || $wkld_id == 5 || $wkld_id == 7} {
            set query_proc_time $mean_service_time_s($wkld_indx)
        } elseif {$wkld_id == 1 || $wkld_id == 2} {
            set query_proc_time [expr [expr 180 * [$gamma_var($wkld_indx) value] + 10000.0]/1000000000.0]
        } elseif {$wkld_id == 6} {
            set query_proc_time [expr [expr 180 * [$gamma_var($wkld_indx) value] + 400.0]/1000000000.0]
        }
        #puts "query_proc_time $query_proc_time"
        set query_done_at [expr $query_proc_time + $process_this_query_at]
        set busy_until [lreplace $busy_until $server_id $server_id \
                                $query_done_at]

        # Respond when the query has been processed
        set cur_app_client [lindex [lindex $app_client_ll $server_id] $wkld_indx]
        set cur_app_server [lindex [lindex $app_server_ll $server_id] $wkld_indx]
        $ns at $query_done_at "$cur_app_server send $resp_size($wkld_indx) \
                {$cur_app_client client-recv $resp_size($wkld_indx) $server_id $query_id $wkld_indx}"
        #puts "STATUS: cwnd: [$sink($server_id) set cwnd_]"

        #puts "------------------------------------------------------------------"

}

puts "All set"
$ns at 0.0 monitor_progress
$ns at $simulation_duration "finish"
$ns run