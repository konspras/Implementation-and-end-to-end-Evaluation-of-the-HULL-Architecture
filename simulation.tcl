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

# in bits
set pacer_bucket_ 100000
# not sure in what (bits/s)
set pacer_rate 150000.0k
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


if {$workload_type == 0} {
    set req_size 100
    set resp_size 100
    set mean_service_time_s 0.0001
    set traffic_duration 1.0
} elseif {$workload_type == 1} {
    set req_size 3500
    set resp_size 2800
    set mean_service_time_s 0.00253
    set traffic_duration 10.0
} elseif {$workload_type == 2} {
    set req_size 100
    set resp_size 100
    set mean_service_time_s 0.00253
    set traffic_duration 10.0
} elseif {$workload_type == 3} {
    set req_size 3500
    set resp_size 2800
    set mean_service_time_s 0.0001
    set traffic_duration 1.0
} elseif {$workload_type == 4} {
    set req_size 3500
    set resp_size 2800
    set mean_service_time_s 0.00253
    set traffic_duration 10.0
} else {
    set req_size 3500
    set resp_size 2800
    set mean_service_time_s 0.00253
    set traffic_duration 10.0
}

set exp_distr_mean [expr [expr 1.0/[expr $server_load/100.0]] \
                        *$mean_service_time_s]
set simulation_duration 100
set traffic_start_time 1.0

#Define a 'finish' procedure
proc finish {} {
    global ns nf tf qf tchan_ tcp num_flows sendTimesList receiveTimesList result_path \
            file_ident DCTCP
    dispRes $num_flows $sendTimesList $receiveTimesList
    saveToFile $result_path $file_ident $sendTimesList $receiveTimesList $num_flows
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

#Set Agents. For each server, a FullTcp agent and a TcpApp Application are created.
for {set i 0} {$i < $num_flows} {incr i} {
    set tcp($i) [new Agent/TCP/FullTcp]
    set sink($i) [new Agent/TCP/FullTcp]
    $ns attach-agent $client_node $tcp($i)
    $ns attach-agent $s($i) $sink($i)
    $tcp($i) set fid_ [expr $i]
    $sink($i) set fid_ [expr $i]
    $ns connect $tcp($i) $sink($i)
    $sink($i) listen

    #Set client application
    set app_client($i) [new Application/TcpApp $tcp($i)]
    #Set server application
    set app_server($i) [new Application/TcpApp $sink($i)]
    #Connect them
    $app_client($i) connect $app_server($i)
    
}



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

# list of lists. Holds, for each server, the times a query was sent/received
# - currently the same for each query id.
set sendTimesList []
set receiveTimesList []
# For each server, the time until it is busy processing a query.
set busy_until []

set send_interval [new RandomVariable/Exponential]
set gamma_var [new RandomVariable/Gamma]
# Interval depends on desired load. For load 1, a query is sent at an interval
# equal to the servers mean service time.
$send_interval set avg_ $exp_distr_mean
$gamma_var set alpha_ 0.7
$gamma_var set beta_ 20000
 
# Initialize lists.. must find better way...
proc initialize_lists {} {
    global sendTimesList receiveTimesList busy_until num_flows
    for {set i 0} {$i < $num_flows} {incr i} {
            lappend sendTimesList 0.0
            lappend receiveTimesList 0.0
            lappend busy_until 0.0
    }
}
# Send requests for $simulation duration time
initialize_lists
set query_id 0
set nextQueryTime [expr [$send_interval value] + $traffic_start_time]
set traffic_end_time [expr $traffic_start_time + $traffic_duration]
while {$nextQueryTime < $traffic_end_time} {
    #puts "nextQueryTime is $nextQueryTime"
    #puts "sendTimesList is: $sendTimesList"
    for {set i 0} {$i < $num_flows} {incr i} {
        $ns at $nextQueryTime "$app_client($i) send $req_size {$app_server($i) \
                                server-recv $req_size $i $query_id}"
        #Register sending time for the client apps
        set curSendList [lindex $sendTimesList $i]
        #set newSendList [lappend curSendList $nextQueryTime]
        set sendTimesList [lreplace $sendTimesList $i $i [lappend curSendList $nextQueryTime]]
        
        # set sendTimesList [lreplace $sendTimesList $i $i \
        #                      [lappend [lindex $sendTimesList $i] $nextQueryTime]]
    }
    set nextQueryTime [expr $nextQueryTime + [$send_interval value]]
    incr query_id
}



Application/TcpApp instproc client-recv { size connection_id query_id } {
        global ns app_server app_client sendTimesList receiveTimesList send_interval \
                 tcp

        #puts "[$ns now] CLIENT received $size bytes response for query $query_id from server \
                        $connection_id"

        # Register response arrival time
        set curRecList [lindex $receiveTimesList $connection_id]
        #set newRecList [lappend curRecList [$ns now]]
        set receiveTimesList [lreplace $receiveTimesList $connection_id \
                                        $connection_id [lappend curRecList [$ns now]]]
        # set receiveTimesList [lreplace $receiveTimesList $connection_id $connection_id \
        #                                  [lappend \
        #                                  [lindex $receiveTimesList $connection_id] \
        #                                  [$ns now]]]
        #puts "STATUS: cwnd: [$tcp($connection_id) set cwnd_]"
        #puts "================================================================"

}

Application/TcpApp instproc server-recv { size connection_id query_id } {
        global ns app_server app_client sendTimesList receiveTimesList \
                 busy_until gamma_var resp_size sink workload_type \
                 mean_service_time_s

        #puts "[$ns now] SERVER $connection_id receives $size bytes query $query_id from client. \
                        Server is busy until [lindex $busy_until $connection_id]"
        set cur_time [$ns now]
        set occupied_until [lindex $busy_until $connection_id]
        #mathfunc was added in tcl 8.5...
        if {$cur_time > $occupied_until} {
                set process_this_query_at $cur_time
                #puts "Processing right away"
        } else {
                set process_this_query_at $occupied_until
                #puts "currently busy"
        }
        if {$workload_type == 0 || $workload_type == 3 || $workload_type == 4} {
            set query_proc_time $mean_service_time_s
        } elseif {$workload_type == 1 || $workload_type == 2} {
            set query_proc_time [expr [expr 180 * [$gamma_var value] + 10000.0]/1000000000.0]
        }
        #puts "query_proc_time $query_proc_time"
        set query_done_at [expr $query_proc_time + $process_this_query_at]
        set busy_until [lreplace $busy_until $connection_id $connection_id \
                                $query_done_at]

        # Respond when the query has been processed
        $ns at $query_done_at "$app_server($connection_id) send $resp_size \
                {$app_client($connection_id) client-recv $resp_size $connection_id $query_id}"
        #puts "STATUS: cwnd: [$sink($connection_id) set cwnd_]"

        #puts "------------------------------------------------------------------"

}



$ns at $simulation_duration "finish"
$ns run