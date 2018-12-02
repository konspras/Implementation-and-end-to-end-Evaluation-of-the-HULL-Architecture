set wl 4101

for {set i 0} {$i < [string length $wl]} {incr i} {
	set cw [string index $wl $i]
	for {set j 0} {$j < 10} {incr j} {
		set tcp($j) $j
		#puts $tcp($j)
	}
}

set st [string index $wl 0]
append st [string index $wl 1]
# puts $st
# puts [expr 2*5+1]
# puts [string range $wl 0 2]



set tcp_ll {}
for {set wkld 0} {$wkld < 2} {incr wkld} {
    for {set i 0} {$i < 5} {incr i} {
    	puts "-----$wkld$i-----"
    	if {$wkld > 0} {
    		set cur_tcp_lst [lindex $tcp_ll $i]
			set tcp_ll [lreplace $tcp_ll $i $i [lappend cur_tcp_lst $wkld$i]]
		} else {
			lappend tcp_ll $wkld$i
		}
		puts $tcp_ll
	}
}


