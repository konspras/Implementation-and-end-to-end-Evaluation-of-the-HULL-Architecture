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

# in bits (as hw impl of HULL)
set pacer_bucket_ 24000
# not sure in what (bits/s)
set pacer_rate 100.0M
#set pacer_rate [expr $link_speed + 50 ]
# in pkts
set pacer_qlen $queue_size

# in ms
set link_latency 0.05ms

# DCTCP
#set DCTCP_K  20
set DCTCP_g  [expr 1.0/16.0]

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
# Queue/RED set bytes_ false
# Queue/RED set queue_in_bytes_ true
# Queue/RED set mean_pktsize_ $pktSize
Queue/RED set gentle_ false
Queue/RED set q_weight_ 1.0
Queue/RED set mark_p_ 1.0
# in packets (def size is 500B)
Queue/RED set thresh_ $DCTCP
Queue/RED set maxthresh_ $DCTCP
Queue/RED set drop_prio_ false
Queue/RED set deque_prio_ false

set num_workloads [string length $workload_type]
for {set i 0} {$i < $num_workloads} {incr i} {
    set wk_type($i) [string index $workload_type $i]
    set wk_server_load($i) [string range $server_load [expr 2 * $i] [expr 2 * $i + 1]]
    if {$wk_type($i) == 0} {
        set req_size($i) 100
        set resp_size($i) 100
        set mean_service_time_s($i) 0.0001
        set traffic_duration($i) 2.0
    } elseif {$wk_type($i) == 1} {
        set req_size($i) 3500
        set resp_size($i) 2800
        set mean_service_time_s($i) 0.00253
        set traffic_duration($i) 2.0
    } elseif {$wk_type($i) == 2} {
        set req_size($i) 100
        set resp_size($i) 100
        set mean_service_time_s($i) 0.00253
        set traffic_duration($i) 10.0
    } elseif {$wk_type($i) == 3} {
        set req_size($i) 3500
        set resp_size($i) 2800
        set mean_service_time_s($i) 0.0001
        set traffic_duration($i) 10.0
    } elseif {$wk_type($i) == 4} {
        set req_size($i) 3500
        set resp_size($i) 2800
        set mean_service_time_s($i) 0.00253
        set traffic_duration($i) 10.0
    } else {
        set req_size($i) 3500
        set resp_size($i) 2800
        set mean_service_time_s($i) 0.00253
        set traffic_duration($i) 10.0
    }
    set exp_distr_mean($i) [expr [expr 1.0/[expr $wk_server_load($i)/100.0]] \
                        *$mean_service_time_s($i)]
    set pace [expr  8 * $req_size($i) / $exp_distr_mean($i) / 1000000.0]
    set pkts_per_req [expr ceil( $req_size($i) / 536.0 )]
    set pkts_to_be_sent [expr 1 / $exp_distr_mean($i) * $traffic_duration($i) * $pkts_per_req]
    puts "Packets expected to be sent by workload $wk_type($i) = $pkts_to_be_sent"
    puts "Mean pace of workload $wk_type($i) = $pace (Mbps)"
    puts "Mean total traffic of workload $wk_type($i) = [expr $num_flows*$pace] (Mbps)"

}

set simulation_duration 100
set traffic_start_time 1.0

#Define a 'finish' procedure
proc finish {} {
    global ns nf tf qf tchan_ tcp_ll num_flows sendTimesList receiveTimesList result_path \
            file_ident DCTCP num_workloads wk_type
    # TODO: Fix dispRes (tcp)
    dispRes $num_flows $num_workloads $sendTimesList $receiveTimesList
    for {set wkld 0} {$wkld < $num_workloads} {incr wkld} {
        set send_lst [lindex $sendTimesList $wkld]
        set recv_lst [lindex $receiveTimesList $wkld]
        saveToFile $result_path "load$file_ident|wkld$wk_type($wkld)" $send_lst $recv_lst $num_flows
    }
    $ns flush-trace
    #Close the NAM trace file
    #close $nf
    close $tf
    if {$DCTCP != 0} {
        close $tchan_
    }
    close $qf
    #Execute NAM on the trace file
    #exec nam out.nam &
    exit 0
}


set ns [new Simulator]

set tf [open out.tr w]
$ns trace-all $tf

# set nf [open out.nam w]
# $ns namtrace-all $nf

# Nodes ------------------------------------------------------------------------
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
        $ns simplex-link-op $s($i) $switch_node insert-hullPacer $server_pacer($i)
    }
}

# Agents -----------------------------------------------------------------------

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
Agent/TCP set window_ 1256
# boolean: re-init cwnd after connection goes idle.  On by default. 
# used true from reproduc until 18/11. Setting to false bcs of example
Agent/TCP set slow_start_restart_ false
# def is 1. Not clear what it is. dctcp example has it at 0
Agent/TCP set windowOption_ 0
# probly smthing to do with simulation sampling. extreme (0.000001 <- dctcp
# reproductions study (was using until 19/11)) - 0.01 is default and also used in example. 
Agent/TCP set tcpTick_ 0.000001
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

if {$DCTCP != 0} {
    # def is 0
    Agent/TCP set ecn_ 1
    # def is 0
    Agent/TCP set old_ecn_ 1
    
    Agent/TCP set ecnhat_ true
    Agent/TCPSink set ecnhat_ true
    Agent/TCP set ecnhat_g_ $DCTCP_g;
}

if {$has_PQ} {
    Agent/TCP set ecn_ 1
    Agent/TCP set old_ecn_ 1
}

# Set Agents. One flow per application per server. List of lists (ll). frst define
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
# puts "number of wkl types = [array size wk_type]"
# puts $flow_id
# puts $tcp_ll 
# puts $sink_ll 
# puts $app_client_ll 
# puts $app_server_ll 
# queue monitoring
set qf [open "$result_path/q_mon_$file_ident" w]
set qmon_size [$ns monitor-queue $switch_node $client_node $qf 0.01]
[$ns link $switch_node $client_node] queue-sample-timeout

if {$DCTCP != 0} {
    set cl_sw_q [[$ns link $switch_node $client_node] queue]
    set tchan_ [open "$result_path/trace_q_$file_ident" w]
    $cl_sw_q trace curq_
    #$cl_sw_q trace ave_
    $cl_sw_q attach $tchan_
}
# Network Setup Complete - Proceed with sending queries --------------------------
#---------------------------------------------------------------------------------


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

#loop over all workloads...
for {set wkld 0} {$wkld < $num_workloads} {incr wkld} {
    set send_interval [new RandomVariable/Exponential]
    set gamma_var($wkld) [new RandomVariable/Gamma]
    # Interval depends on desired load. For load 1, a query is sent at an interval
    # equal to the servers mean service time.
    $send_interval set avg_ $exp_distr_mean($wkld)
    $gamma_var($wkld) set alpha_ 0.7
    $gamma_var($wkld) set beta_ 20000

    # Send requests for $simulation duration time
    set query_id 0
    set nextQueryTime [expr [$send_interval value] + $traffic_start_time]
    set traffic_end_time [expr $traffic_start_time + $traffic_duration($wkld)]
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

#puts $sendTimesList

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

Application/TcpApp instproc server-recv { size server_id query_id wkld_id wkld_indx} {
        global ns app_server app_client sendTimesList receiveTimesList \
                 busy_until gamma_var resp_size sink workload_type \
                 mean_service_time_s app_client_ll app_server_ll

        #puts "[$ns now] SERVER $server_id receives $size bytes query $query_id from client. \
                        Server is busy until [lindex $busy_until $server_id]"
        set cur_time [$ns now]
        set occupied_until [lindex $busy_until $server_id]
        #mathfunc was added in tcl 8.5...
        if {$cur_time > $occupied_until} {
                set process_this_query_at $cur_time
                #puts "Processing right away"
        } else {
                set process_this_query_at $occupied_until
                #puts "currently busy"
        }
        if {$wkld_id == 0 || $wkld_id == 3 || $wkld_id == 4} {
            set query_proc_time $mean_service_time_s($wkld_indx)
        } elseif {$wkld_id == 1 || $wkld_id == 2} {
            set query_proc_time [expr [expr 180 * [$gamma_var($wkld_indx) value] + 10000.0]/1000000000.0]
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



$ns at $simulation_duration "finish"
$ns run