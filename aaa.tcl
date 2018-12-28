
#
# Create a simple star topology

proc dispRes {} {
    global tcp num_flows
    
    for {set i 0} {$i < $num_flows} {incr i} {
        set numPktsSent [$tcp($i) set ndatapack_]
        set numBytesSent [$tcp($i) set ndatabytes_]
        set numPktsRetr [$tcp($i) set nrexmitpack_]
        set numEcnAffected [$tcp($i) set necnresponses_]
        set numAcksRec [$tcp($i) set nackpack_]
        set numTimeCwdReduce [$tcp($i) set ncwndcuts_]
        puts "Packets sent by $i: $numPktsSent"
        puts "Packets retransmitted by $i: $numPktsRetr"
        puts "Acks received by $i: $numAcksRec"
        puts "times cwnd was reduced ecn at $i: $numEcnAffected"
        puts "times cwnd was reduced at $i: $numTimeCwdReduce"
        puts "============================================="
    }

}

#Define a 'finish' procedure
proc finish {} {
    global ns nf tf qf_size tcl_dir
    dispRes
    $ns flush-trace
    #Close the NAM trace file
    close $nf
    close $tf
    close $qf_size
    #Execute NAM on the trace file
    exec nam out.nam &
    exit 0
}

set congestion_alg "DCTCP"
set out_q_file "q_file"
set num_flows 2

# samp_int (sec)
set samp_int 0.01
# q_size (pkts)
set q_size 20
# link_cap (Mbps)
set link_cap 2
# tcp_window (pkts)
set tcp_window 1000000
# run_time (sec)
set run_time 10.0
# pktSize (bytes)
set pktSize 1460

#### DCTCP Parameters ####
# DCTCP_K (pkts)
set DCTCP_K 5
# DCTCP_g (0 < g < 1)
set DCTCP_g 0.0625
# ackRatio
set ackRatio 1

##### Switch Parameters ####
set drop_prio_ false
set deque_prio_ false

#set tcl_dir $::env(TCL_DIR)

#Create a simulator object
set ns [new Simulator]

#Define different colors for data flows (for NAM)
$ns color 1 Blue
$ns color 2 Red

#Open the Trace file
set tf [open out.tr w]
$ns trace-all $tf

#Open the NAM trace file
set nf [open out.nam w]
$ns namtrace-all $nf

#Create switch_node, dst_node, and num_flows src nodes
set switch_node [$ns node]
set dst_node [$ns node]

for {set i 0} {$i < $num_flows} {incr i} {
    set h($i) [$ns node]
}

# Queue options
Queue set limit_ $q_size

Queue/DropTail set mean_pktsize_ [expr $pktSize+40]
Queue/DropTail set drop_prio_ $drop_prio_
Queue/DropTail set deque_prio_ $deque_prio_

#Queue/RED set bytes_ false
#Queue/RED set queue_in_bytes_ true
Queue/RED set mean_pktsize_ $pktSize
Queue/RED set setbit_ true
Queue/RED set gentle_ false
Queue/RED set q_weight_ 1.0
Queue/RED set mark_p_ 1.0
Queue/RED set thresh_ $DCTCP_K
Queue/RED set maxthresh_ $DCTCP_K
Queue/RED set drop_prio_ $drop_prio_
Queue/RED set deque_prio_ $deque_prio_


#Create links between the nodes
if {[string compare $congestion_alg "DCTCP"] == 0} { 
    set queue_type RED
} else {
    set queue_type DropTail
}

$ns duplex-link $switch_node $dst_node 0.1Mb 10ms $queue_type

for {set i 0} {$i < $num_flows} {incr i} {
    $ns duplex-link $h($i) $switch_node 1Mb 10ms $queue_type
}


##Give node position (for NAM)
#$ns duplex-link-op $h1 $s1 orient right-down
#$ns duplex-link-op $h2 $s1 orient right-up
#$ns duplex-link-op $s1 $h3 orient right

#Monitor the queue for link (s1-h3). (for NAM)
$ns duplex-link-op $switch_node $dst_node queuePos 0.5

# HOST options
Agent/TCP set window_ $tcp_window
Agent/TCP set windowInit_ 2
Agent/TCP set packetSize_ $pktSize
Agent/TCP/FullTcp set segsize_ $pktSize

if {[string compare $congestion_alg "DCTCP"] == 0} {
    puts "Setting up DCTCP"
    Agent/TCP set ecn_ 1
    Agent/TCP set old_ecn_ 1
    Agent/TCP/FullTcp set spa_thresh_ 0
    Agent/TCP set slow_start_restart_ true
    Agent/TCP set windowOption_ 0
    Agent/TCP set tcpTick_ 0.000001
#    Agent/TCP set minrto_ $min_rto
#    Agent/TCP set maxrto_ 2
    
    Agent/TCP/FullTcp set nodelay_ true; # disable Nagle
    Agent/TCP/FullTcp set segsperack_ $ackRatio;
    Agent/TCP/FullTcp set interval_ 0.000006

    Agent/TCP set ecnhat_ true
    Agent/TCPSink set ecnhat_ true
    Agent/TCP set ecnhat_g_ $DCTCP_g;

    for {set i 0} {$i < $num_flows} {incr i} {
        set tcp($i) [new Agent/TCP/FullTcp]
        set sink($i) [new Agent/TCP/FullTcp]
        $ns attach-agent $h($i) $tcp($i)
        $ns attach-agent $dst_node $sink($i)
        $tcp($i) set fid_ [expr $i]
        $sink($i) set fid_ [expr $i]
        $ns connect $tcp($i) $sink($i)
        # set up TCP-level connections
        $sink($i) listen
    }

} else {
    puts "Setting up NON DCTCP agents"
    for {set i 0} {$i < $num_flows} {incr i} {
        #set tcp($i) [$ns create-connection TCP/Linux $h($i) TCPSink/Sack1 $dst_node [expr $i]]
        set tcp($i) [new Agent/TCP/FullTcp]
        set sink($i) [new Agent/TCP/FullTcp]
        $ns attach-agent $h($i) $tcp($i)
        $ns attach-agent $dst_node $sink($i)
        $tcp($i) set fid_ [expr $i]
        $sink($i) set fid_ [expr $i]
        $ns connect $tcp($i) $sink($i)
        $sink($i) listen
    }

    #set tcp1 [$ns create-connection TCP/Reno $h1 TCPSink $h3 1]
    #set tcp2 [$ns create-connection TCP/Reno $h2 TCPSink $h3 2]
}

for {set i 0} {$i < $num_flows} {incr i} {
    set ftp($i) [$tcp($i) attach-source FTP]
    $ftp($i) set type_ FTP 
}

# queue monitoring
set qf_size [open out_q_file w]
set qmon_size [$ns monitor-queue $switch_node $dst_node $qf_size $samp_int]
[$ns link $switch_node $dst_node] queue-sample-timeout

#Schedule events for the CBR and FTP agents
for {set i 0} {$i < $num_flows} {incr i} {
    $ns at 0.1 "$ftp($i) start"
    $ns at [expr $run_time - 0.5] "$ftp($i) stop"
}

#Call the finish procedure after run_time seconds of simulation time
$ns at $run_time "finish"

#Run the simulation
$ns run