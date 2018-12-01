proc calculate_throuhput { flow_id bytes_sent bytes_retr sendTimesList receiveTimesList } {

    set bytes_recvd [expr $bytes_sent - $bytes_retr]
    set start_time [lindex [lindex $sendTimesList $flow_id] 1]
    set end_time [lindex [lindex $receiveTimesList $flow_id] \
                     [expr [llength [lindex $receiveTimesList $flow_id]]-1]]

    set duration [expr $end_time - $start_time]
    set goodput [expr ($bytes_recvd*8)/($duration * 1000000)]
    set throughput [expr ($bytes_sent*8)/($duration * 1000000)]

    puts "duration: $duration (s)"
    puts "GOODPUT: $goodput (Mb/s)"
    puts "THROUGHPUT: $throughput (Mb/s)"

}

proc dispRes { num_flows sendTimesList receiveTimesList } {  
    global tcp
    for {set i 0} {$i < $num_flows} {incr i} {
        set numPktsSent [$tcp($i) set ndatapack_]
        set numBytesSent [$tcp($i) set ndatabytes_]
        set numAcksRec [$tcp($i) set nackpack_]
        set numRexMit [$tcp($i) set nrexmit_]
        set numPktsRetr [$tcp($i) set nrexmitpack_]
        set numRexMitBytes [$tcp($i) set nrexmitbytes_]
        set numEcnAffected [$tcp($i) set necnresponses_]
        set numTimesCwdReduce [$tcp($i) set ncwndcuts_]
        set numTimesCwdRedCong [$tcp($i) set ncwndcuts1_]
        puts "============================================="
        calculate_throuhput $i $numBytesSent $numRexMitBytes $sendTimesList $receiveTimesList
        puts "Packets sent by $i: $numPktsSent"
        puts "Packets retransmitted by $i: $numPktsRetr"
        puts "Acks received by $i: $numAcksRec"
        puts "Num of retr timeouts when there was data outstanding at $i: $numRexMit"
        puts "Times cwnd was reduced bcs of ecn at $i: $numEcnAffected"
        puts "Times cwnd was reduced at $i: $numTimesCwdReduce"
        puts "Times cwnd was reduced bcs of cong at $i: $numTimesCwdRedCong"
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



