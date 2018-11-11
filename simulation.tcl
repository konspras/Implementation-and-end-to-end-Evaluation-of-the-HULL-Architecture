#package require csv

#cmd args order: num_flows, server_load

set result_path [lindex $argv 0]
# used to identify the output files
set file_ident [lindex $argv 1]
set num_flows [lindex $argv 2]
# server load in %
set server_load [lindex $argv 3]
set workload_type [lindex $argv 4]

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

} else {
    set req_size 3500
    set resp_size 2800
    set mean_service_time_s 0.00253
    set traffic_duration 10.0

}

set exp_distr_mean [expr [expr 1.0/[expr $server_load/100.0]] \
                        *$mean_service_time_s]
set simulation_duration 50
set traffic_start_time 1.0

proc dispRes {} {
    global tcp num_flows server_load workload_type sendTimesList receiveTimesList
    
    for {set i 0} {$i < $num_flows} {incr i} {
        puts "num_flows: $num_flows, server_load: $server_load, workload_type: \
                $workload_type"
        set numPktsSent [$tcp($i) set ndatapack_]
        set numBytesSent [$tcp($i) set ndatabytes_]
        set numAcksRec [$tcp($i) set nackpack_]
        set numRexMit [$tcp($i) set nrexmit_]
        set numPktsRetr [$tcp($i) set nrexmitpack_]
        set numEcnAffected [$tcp($i) set necnresponses_]
        set numTimesCwdReduce [$tcp($i) set ncwndcuts_]
        set numTimesCwdRedCong [$tcp($i) set ncwndcuts1_]
        puts "============================================="
        puts "Packets sent by $i: $numPktsSent"
        puts "Packets retransmitted by $i: $numPktsRetr"
        puts "Acks received by $i: $numAcksRec"
        puts "Num of retr timeouts when there was data outstanding at $i: $numRexMit"
        puts "Times cwnd was reduced bcs of ecn at $i: $numEcnAffected"
        puts "Times cwnd was reduced at $i: $numTimesCwdReduce"
        puts "Times cwnd was reduced bcs of cong at $i: $numTimesCwdRedCong"
        #puts "send list: $sendTimesList"
        #puts "rcv list: $receiveTimesList"
    }

}

proc saveToFile {} {
    global result_path file_ident sendTimesList receiveTimesList num_flows
        
    #puts "sendTimesList $sendTimesList"
    #puts "receiveTimesList $receiveTimesList"
    set sfp [open "$result_path/send_times$file_ident.csv" w+]
    set rfp [open "$result_path/rec_times$file_ident.csv" w+]
    set num_iter [llength [lindex $sendTimesList 0]]
    for {set i 1} {$i < $num_iter} {incr i} {
        for {set j 0} {$j < $num_flows} {incr j} {
            puts -nonewline $sfp [lindex [lindex $sendTimesList $j] $i]
            puts -nonewline $sfp ","
            puts -nonewline $rfp [lindex [lindex $receiveTimesList $j] $i]
            puts -nonewline $rfp ","
        }
        puts -nonewline $sfp "\n"
        puts -nonewline $rfp "\n"
    } 
}

#Define a 'finish' procedure
proc finish {} {
    global ns nf tf
    dispRes
    saveToFile
    $ns flush-trace
    #Close the NAM trace file
    #close $nf
    close $tf
    #Execute NAM on the trace file
    #exec nam out.nam &
    exit 0
}

set ns [new Simulator]

set tf [open out.tr w]
$ns trace-all $tf

# set nf [open out.nam w]
# $ns namtrace-all $nf

#Nodes
set switch_node [$ns node]
set client_node [$ns node]
for {set i 0} {$i < $num_flows} {incr i} {
    set s($i) [$ns node]
}

#Connect Nodes
$ns duplex-link $switch_node $client_node 1000Mb 0.1ms DropTail

for {set i 0} {$i < $num_flows} {incr i} {
    $ns duplex-link $s($i) $switch_node 1000Mb 0.1ms DropTail
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

# Network Setup Complete - Proceed with sending queries ----------------------
#-----------------------------------------------------------------------------

# list of lists. Holds, for each server, the times a query was sent/received
# - currently the same for each query id.
set sendTimesList []
set receiveTimesList []
# The differences between request send and receive time
set diffs []
# For each server, the time until it is busy processing a query.
set busy_until []

set send_interval [new RandomVariable/Exponential]
set gamma_var [new RandomVariable/Gamma]
# Interval depends on desired load. For load 1, a query is sent at an interval
# equal to the servers mean service time.
$send_interval set avg_ $exp_distr_mean
$gamma_var set alpha_ 0.7
$gamma_var set beta_ 20000
 
# Initiate lists.. must find better way...
proc initiate_lists {} {
    global sendTimesList receiveTimesList diffs busy_until num_flows
    for {set i 0} {$i < $num_flows} {incr i} {
            lappend sendTimesList 0.0
            lappend receiveTimesList 0.0
            lappend diffs 0.0
            lappend busy_until 0.0
    }
}

# Send requests for $simulation duration time
initiate_lists
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
        set newSendList [lappend curSendList $nextQueryTime]
        set sendTimesList [lreplace $sendTimesList $i $i $newSendList]
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
        set newRecList [lappend curRecList [$ns now]]
        set receiveTimesList [lreplace $receiveTimesList $connection_id \
                                        $connection_id $newRecList]
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
        if {$workload_type == 0} {
            set query_proc_time $mean_service_time_s
        } else {
            set query_proc_time [expr [expr 180 * [$gamma_var value] + 10000.0]/1000000000.0]
        }
        #puts "query_proc_time $query_proc_time"
        set query_done_at [expr $query_proc_time + $process_this_query_at]
        set busy_until [lreplace $busy_until $connection_id $connection_id \
                                $query_done_at]

        # Respond when the quety has been processed
        $ns at $query_done_at "$app_server($connection_id) send $resp_size \
                {$app_client($connection_id) client-recv $resp_size $connection_id $query_id}"
        #puts "STATUS: cwnd: [$sink($connection_id) set cwnd_]"

        #puts "------------------------------------------------------------------"

}


#$ns at 1.0 "$app_client(0) send 100 \bs"$app_server(0) app-recv 100\bs""

$ns at $simulation_duration "finish"
$ns run