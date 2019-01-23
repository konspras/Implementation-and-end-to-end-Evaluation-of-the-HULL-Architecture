set TIME_start [clock clicks -milliseconds]
for {set i 0} {$i<100000} {incr i} {
	incr i
	set i [expr $i - 1]
}
set TIME_taken [expr [clock clicks -milliseconds] - $TIME_start]

puts "$TIME_taken"