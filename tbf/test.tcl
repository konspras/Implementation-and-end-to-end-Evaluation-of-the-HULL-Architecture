set wl 41

for {set i 0} {$i < [string length $wl]} {incr i} {
	set cw [string index $wl $i]
	for {set j 0} {$j < 10} {incr j} {
		set tcp($j) $j
		puts $tcp($j)
	}
}

