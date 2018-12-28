
proc calculate_throuhput { flow_id bytes_sent bytes_retr wkld sendTimesList receiveTimesList } {

    set this_wklds_sendlist [lindex $sendTimesList $wkld]
    set this_wklds_reclist [lindex $receiveTimesList $wkld]

    set bytes_recvd [expr $bytes_sent - $bytes_retr]
    set start_time [lindex [lindex $this_wklds_sendlist $flow_id] 1]
    set end_time [lindex [lindex $this_wklds_reclist $flow_id] \
                     [expr [llength [lindex $this_wklds_reclist $flow_id]]-1]]

    set duration [expr $end_time - $start_time]
    set goodput [expr ($bytes_recvd*8)/($duration * 1000000)]
    set throughput [expr ($bytes_sent*8)/($duration * 1000000)]

    puts "Flow duration: $duration (s)"
    puts "Flow GOODPUT: $goodput (Mb/s)"
    puts "Flow THROUGHPUT: $throughput (Mb/s)"

}

proc dispRes { num_flows num_workloads sendTimesList receiveTimesList } {  
    global tcp_ll
    for {set wkld 0} {$wkld < $num_workloads} {incr wkld} {
        puts "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~Workload $wkld~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
        for {set i 0} {$i < $num_flows} {incr i} {
            set tcp_agent [lindex [lindex $tcp_ll $i] $wkld]

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
            calculate_throuhput $i $numBytesSent $numRexMitBytes $wkld $sendTimesList $receiveTimesList
            puts "Packets sent by tcp agent $i: $numPktsSent"
            puts "Packets retransmitted by tcp agent $i: $numPktsRetr"
            puts "Acks received by tcp agent $i: $numAcksRec"
            puts "Num of retr timeouts when there was data outstanding at $i: $numRexMit"
            puts "Times cwnd was reduced bcs of ecn at $i: $numEcnAffected"
            puts "Times cwnd was reduced at $i: $numTimesCwdReduce"
            puts "Times cwnd was reduced bcs of cong at $i: $numTimesCwdRedCong"
        }

    }
}

proc saveToFile { result_path file_ident sendTimesList receiveTimesList num_flows } {        
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



