#
# Copyright (c) Xerox Corporation 1997. All rights reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the
# Free Software Foundation; either version 2 of the License, or (at your
# option) any later version.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
#
# Linking this file statically or dynamically with other modules is making
# a combined work based on this file.  Thus, the terms and conditions of
# the GNU General Public License cover the whole combination.
#
# In addition, as a special exception, the copyright holders of this file
# give you permission to combine this file with free software programs or
# libraries that are released under the GNU LGPL and with code included in
# the standard release of ns-2 under the Apache 2.0 license or under
# otherwise-compatible licenses with advertising requirements (or modified
# versions of such code, with unchanged license).  You may copy and
# distribute such a system following the terms of the GNU GPL for this
# file and the licenses of the other code concerned, provided that you
# include the source code of that other code when and as the GNU GPL
# requires distribution of source code.
#
# Note that people who make modified versions of this file are not
# obligated to grant this special exception for their modified versions;
# it is their choice whether to do so.  The GNU General Public License
# gives permission to release a modified version without this exception;
# this exception also makes it possible to release a modified version
# which carries forward this exception.
#


# This example script demonstrates using the token bucket filter as a
# traffic-shaper. 
# There are 2 identical source models(exponential on/off) connected to a common
# receiver. One of the sources is connected via a tbf whereas the other one is 
# connected directly.The tbf parameters are such that they shape the exponential
# on/off source to look like a cbr-like source.

set ns [new Simulator]
set client_1 [$ns node]
set client_2 [$ns node]
set switch [$ns node]
set server [$ns node]
set f [open out.tr w]
$ns trace-all $f
set nf [open out.nam w]
$ns namtrace-all $nf
$ns color 0 red
$ns color 1 blue

# CONFIGURE LINKS
$ns simplex-link $client_1 $switch 0.2Mbps 100ms DropTail
$ns simplex-link $switch $client_1 0.2Mbps 100ms DropTail

$ns simplex-link $client_2 $switch 0.2Mbps 100ms DropTail
$ns simplex-link $switch $client_2 0.2Mbps 100ms DropTail

$ns simplex-link $server $switch 0.2Mbps 100ms DropTail
$ns simplex-link $switch $server 0.2Mbps 100ms DropTail

# CONFIGURE AGENTS
set tcp_1 [new Agent/TCP/FullTcp]
set tcp_2 [new Agent/TCP/FullTcp]
$tcp_1 set fid_ 0
$tcp_2 set fid_ 1
set sink_1 [new Agent/TCP/FullTcp]
set sink_2 [new Agent/TCP/FullTcp]
$sink_1 set fid_ 0
$sink_2 set fid_ 1
$ns attach-agent $client_1 $tcp_1
$ns attach-agent $client_2 $tcp_2
$ns attach-agent $server $sink_1
$ns attach-agent $server $sink_2

$ns connect $tcp_1 $sink_1
$ns connect $tcp_2 $sink_2
$sink_1 listen
$sink_2 listen

# CONFIGURE APPLICATIONS
#Set client_1 application
set app_client_1 [new Application/Traffic/Exponential]
set app_client_2 [new Application/Traffic/Exponential]
$app_client_1 set packetSize_ 128
$app_client_2 set packetSize_ 128
$app_client_1 set burst_time_ [expr 20.0/64]
$app_client_2 set burst_time_ [expr 20.0/64]
$app_client_1 set idle_time_ 325ms
$app_client_2 set idle_time_ 325ms
$app_client_1 set rate_ 65.536k
$app_client_2 set rate_ 65.536k

# Attach agent to application
$app_client_1 attach-agent $tcp_1
$app_client_2 attach-agent $tcp_2

# Create and attach PACER
set pacer [new HullPacer]
$pacer set bucket_ 1024
$pacer set rate_ 65.536k
$pacer set qlen_  100

#$ns attach-hullPacer-agent $client_1 $tcp_1 $pacer
$ns simplex-link-op $client_1 $switch insert-hullPacer $pacer

$ns at 0.0 "$app_client_1 start"
$ns at 0.0 "$app_client_2 start"
$ns at 5.0 "$app_client_1 stop"
$ns at 5.0 "$app_client_2 stop"
$ns at 5.0 "close $f;close $nf;exec nam out.nam &;exit 0"
$ns run


# set ns [new Simulator]
# set n0 [$ns node]
# set n1 [$ns node]
# set n2 [$ns node]
# set f [open out.tr w]
# $ns trace-all $f
# set nf [open out.nam w]
# $ns namtrace-all $nf

# set trace_flow 1

# $ns color 0 red
# $ns color 1 blue

# $ns duplex-link $n2 $n1 0.2Mbps 100ms DropTail
# $ns duplex-link $n0 $n1 0.2Mbps 100ms DropTail

# $ns duplex-link-op $n2 $n1 orient right-down
# $ns duplex-link-op $n0 $n1 orient right-up

# # Set receiver
# set rcvr [new Agent/SAack]
# $ns attach-agent $n1 $rcvr

# # Set up Application 1
# set exp1 [new Application/Traffic/Exponential]
# $exp1 set packetSize_ 128
# $exp1 set burst_time_ [expr 20.0/64]
# $exp1 set idle_time_ 325ms
# $exp1 set rate_ 65.536k

# set a [new Agent/UDP]
# $a set fid_ 0
# $exp1 attach-agent $a

# set tbf [new TBF]
# $tbf set bucket_ 1024
# $tbf set rate_ 32.768k
# $tbf set qlen_  100

# $ns attach-tbf-agent $n0 $a $tbf

# $ns connect $a $rcvr

# # Set up Application 2
# set exp2 [new Application/Traffic/Exponential]
# $exp2 set packetSize_ 128
# $exp2 set burst_time_ [expr 20.0/64]
# $exp2 set idle_time_ 325ms
# $exp2 set rate_ 65.536k

# set a2 [new Agent/UDP]
# $a2 set fid_ 1
# $exp2 attach-agent $a2

# $ns attach-agent $n2 $a2

# $ns connect $a2 $rcvr

# $ns at 0.0 "$exp1 start;$exp2 start"
# $ns at 20.0 "$exp1 stop;$exp2 stop;close $f;close $nf;exec nam out.nam &;exit 0"
# $ns run



