source "util.tcl"

set result_path [lindex $argv 0]
# used to identify the output files
set num_flows [lindex $argv 1]
# server load in %
set DCTCP [lindex $argv 2]
# in Mbps
set link_speed [lindex $argv 3]Mb
set has_PQ [lindex $argv 4]
set PQ_rate [lindex $argv 5]
set PQ_thresh [lindex $argv 6]
set queue_size [lindex $argv 7]
set has_pacer [lindex $argv 8]
set label [lindex $argv 9]


# in bits (as hw impl of HULL)
set pacer_bucket_ 24000
# not sure in what (bits/s)
set pacer_rate 100.0M
#set pacer_rate [expr $link_speed + 50 ]
# in pkts
set pacer_qlen $queue_size

# in ms - 5micro
set link_latency 0.005ms

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

set simulation_duration 150.0
set traffic_start_time 1.0
set traffic_stop_time 2.0

#Define a 'finish' procedure
proc finish {} {
    global ns nf tf qf tchan_ num_flows result_path DCTCP thrpt_file
    dispRes $num_flows
    # for {set wkld 0} {$wkld < $num_workloads} {incr wkld} {
    #     set send_lst [lindex $sendTimesList $wkld]
    #     set recv_lst [lindex $receiveTimesList $wkld]
    #     saveToFile $result_path "load$file_ident|wkld$wk_type($wkld)" $send_lst $recv_lst $num_flows
    # }

    $ns flush-trace
    #Close the NAM trace file
    # close $tf
    # if {$DCTCP != 0} {
    #     close $tchan_
    # }
    close $qf
    close $thrpt_file
    # close $nf
    # #Execute NAM on the trace file
    # exec nam out.nam &
    exit 0
}


for {set i 0} {$i < $num_flows} {incr i} {
    set previous_bytes_sent($i) 0.0
    set previous_bytes_retr($i) 0.0
}
set thrpt_interval 0.001
set thrpt_file [open "$result_path/thrpt_mon|$label|$num_flows" w+]
proc throughput_monitor { } {
    global tcp ns previous_bytes_sent previous_bytes_retr thrpt_interval thrpt_file \
            num_flows server_pacer has_pacer
    set sim_time [$ns now]
    set goodput 0.0
    for {set i 0} {$i < $num_flows} {incr i} {
        set numBytesSent [$tcp($i) set ndatabytes_]
        set numRexMitBytes [$tcp($i) set nrexmitbytes_]
        set bytes_sent_interval [expr $numBytesSent - $previous_bytes_sent($i)]
        set bytes_retr_interval [expr $numRexMitBytes - $previous_bytes_retr($i)]

        set previous_bytes_sent($i) $numBytesSent
        set previous_bytes_retr($i) $numRexMitBytes

        set bytes_received_interval [expr $bytes_sent_interval - $bytes_retr_interval]
        # In Mbps
        set tmp [expr ($bytes_received_interval*8)/($thrpt_interval * 1000000)]
        set goodput [expr $goodput + $tmp]
    }
    

    set wndw_len [$tcp(0) set cwnd_]
    set thresh [$tcp(0) set ssthresh_]
    set max_thresh [$tcp(0) set max_ssthresh_]
    set max_cwnd [$tcp(0) set maxcwnd_]
    set timeouts [$tcp(0) set nrexmit_]
    set ecn_rdce [$tcp(0) set necnresponses_]
    set cwnd_rdc [$tcp(0) set ncwndcuts1_]
    if {$has_pacer} {
        set curr_pacer_rate [$server_pacer(0) set rate_]
    } else {
        set curr_pacer_rate "na"
    }
    # set curr_pacer_rate [expr $curr_pacer_rate * 1]
    puts $thrpt_file "$sim_time,$goodput,$wndw_len,$thresh/$max_thresh, \
            {$curr_pacer_rate},-$timeouts-,{$ecn_rdce},-$cwnd_rdc-"

    $ns at [expr $sim_time + $thrpt_interval] throughput_monitor




}

proc avg {nums} {
    upvar $nums numbers
    set sum 0.0
    for {set i 0} {$i < [array size numbers]} { incr i} {
        set sum  [expr $sum + $numbers($i)]

    }
    set average [expr $sum/[array size numbers]]
    return $average
}

proc calculate_throuhput_Mbps { bytes_sent bytes_retr duration} {

    set bytes_recvd [expr $bytes_sent - $bytes_retr]

    set goodput [expr ($bytes_recvd*8)/($duration * 1000000)]
    set throughput [expr ($bytes_sent*8)/($duration * 1000000)]

    return $throughput

}


proc dispRes { num_flows } { 
    global tcp 

    for {set i 0} {$i < $num_flows} {incr i} {
        set tcp_agent $tcp($i)

        set numPktsSent [$tcp_agent set ndatapack_]
        set numBytesSent [$tcp_agent set ndatabytes_]
        set numAcksRec [$tcp_agent set nackpack_]
        set numRexMit [$tcp_agent set nrexmit_]
        set numPktsRetr [$tcp_agent set nrexmitpack_]
        set numRexMitBytes [$tcp_agent set nrexmitbytes_]
        set numEcnAffected [$tcp_agent set necnresponses_]
        set numTimesCwdReduce [$tcp_agent set ncwndcuts_]
        set numTimesCwdRedCong [$tcp_agent set ncwndcuts1_]
        puts "============================================="
        #set thrpt($i) [calculate_throuhput $i $numBytesSent $numRexMitBytes]
        puts "Packets sent by tcp agent $i: $numPktsSent"
        puts "Bytes sent by tcp agent $i: $numBytesSent"
        puts "Packets retransmitted by tcp agent $i: $numPktsRetr"
        puts "Acks received by tcp agent $i: $numAcksRec"
        puts "Num of retr timeouts when there was data outstanding at $i: $numRexMit"
        puts "Times cwnd was reduced bcs of ecn at $i: $numEcnAffected"
        puts "Times cwnd was reduced at $i: $numTimesCwdReduce"
        puts "Times cwnd was reduced bcs of cong at $i: $numTimesCwdRedCong"
    }

    #puts "Average throughput is: [avg thrpt]"

}

set ns [new Simulator]

# set tf [open out.tr w]
# $ns trace-all $tf

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
    $client_pacer set rate_upd_interval_  0.000032
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
            $server_pacer($i) set debug_ 0
        }
        $ns simplex-link-op $s($i) $switch_node insert-hullPacer $server_pacer($i)
    }
}

# Agents -----------------------------------------------------------------------

# CONFIG : https://github.com/camsas/qjump-ns2/blob/master/qjump.tcl
# def is 1000
#Agent/TCP set packetSize_ $packetSize
# def is 536 - example uses 1460.. but the PQ threshold!
#Agent/TCP/FullTcp set segsize_ $packetSize
# default is 20! ex is at 1256, repr is at infin. was not using this until 18/11
# Book sais Upper bound on window size
Agent/TCP set window_ 1256
Agent/TCP set max_ssthresh_ 100000
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
# packets. DCTCP K is in packets. So to get 30K need to set it to 30,000/600 = 50
# and for 6K: 6000/600 = 10
Agent/TCP/FullTcp set segsize_ 600

if {$DCTCP != 0} {
    # def is 0
    Agent/TCP set ecn_ 1
    # def is 0
    Agent/TCP set old_ecn_ 1
    Agent/TCP set ecnhat_ true
    Agent/TCPSink set ecnhat_ true
    Agent/TCP set ecnhat_g_ $DCTCP_g;
}

for {set i 0} {$i < $num_flows} {incr i} {
    #Setup a TCP connection
    set tcp($i) [new Agent/TCP/FullTcp]
    set sink($i) [new Agent/TCP/FullTcp]
    $sink($i) listen
    $ns attach-agent $s($i) $tcp($i)
    $ns attach-agent $client_node $sink($i)
    $tcp($i) set fid_ $i
    $sink($i) set fid_ $i
    $ns connect $tcp($i) $sink($i)
}

for {set i 0} {$i < $num_flows} {incr i} {
    set ftp($i) [$tcp($i) attach-source FTP]
    $ftp($i) set type_ FTP 
}

set qf [open "$result_path/q_mon|$label|$num_flows" w]
set qmon_size [$ns monitor-queue $switch_node $client_node $qf 0.001]
[$ns link $switch_node $client_node] queue-sample-timeout


# Network Setup Complete - Proceed with sending queries --------------------------
#---------------------------------------------------------------------------------
for {set i 0} {$i < $num_flows} {incr i} {
    # $ns at [expr $traffic_start_time] "$ftp($i) send 100000"
    # $ns at [expr $traffic_start_time] "$ftp($i) send 1000000"
    $ns at [expr $traffic_start_time] "$ftp($i) send 100000000"
    # $ns at [expr $traffic_start_time] "$ftp($i) send 1000000000"
    # $ns at [expr $traffic_start_time] "$ftp($i) start"
    # $ns at [expr $traffic_stop_time] "$ftp($i) stop"
}


$ns at 0.0 throughput_monitor
$ns at $simulation_duration "finish"
$ns run