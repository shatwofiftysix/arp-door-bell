#!/bin/tclsh

# requires: tclsh, arp-scan, cat
# arp-scan must run as root

proc main {} {
	set verbose 		  false
	set notifyAll 		true
	set offlineAfter	60 ;# approx 60 seconds

	# these MACs are tied to a person
	# should be using builtin file i/o instead of cat
	set knownMACList ""
	catch  {set knownMACList [split [exec cat arp-directory.txt] "\n"]}
	array set knownMACArray {}
	foreach device $knownMACList {
		set name [lindex $device 0]
		set mac [lindex $device 1]
		set knownMACArray($mac) $name
	}
	if {$verbose} {
		puts "known users:"
		parray knownMACArray
		puts ""
	}

	array set currentMACArray {}

	set initialized false ;# skip first iteration only care about network changes
	while {true} {
		# arp-scan results
		set foundMACList [getLocalMACs]
		# pull into array/hash to remove duplicates
		array set foundMACArray {}
		foreach foundMAC $foundMACList {
			# is the device owner known
			if {[catch {set name $knownMACArray($foundMAC)} err]} {
				set name "unknown"
			}			
			set foundMACArray($foundMAC) $name
		}

		# has anything connected
		foreach {foundMAC name} [array get foundMACArray] {
			if {[catch {set name $currentMACArray($foundMAC)}]} {
				if {$initialized} {
					deviceConnected $foundMAC $name $notifyAll
				}
				set currentMACArray($foundMAC) $name
			}
			set currentMACMissRespArray($foundMAC) 0
		}

		if {!$initialized} {
			set initialized true
			continue
		}

		# has anything disconnected
		foreach {currMac name} [array get currentMACArray] {
			if {[catch {set name $foundMACArray($currMac)}]} {
				incr currentMACMissRespArray($currMac) 
				if {$verbose} {
					puts "$name $currMac miss $currentMACMissRespArray($currMac)"
				}
				if {$currentMACMissRespArray($currMac) >= $offlineAfter} {					
					deviceDisconnected $currMac $name $notifyAll
					unset currentMACArray($currMac)
				}
			}
		}

		unset foundMACArray
		after 1000
	}

	return 0
}

# returns list of MACs
proc getLocalMACs {} {
	set arpRes [exec arp-scan --localnet --ignoredups --quiet]
	# set arpList [regexp -all -inline {[[\w\d]{2}:]{5}[\w\d]{2}} $arpRes] ;# cyka
	set arpList [regexp -all -inline {[\w\d]{2}:[\w\d]{2}:[\w\d]{2}:[\w\d]{2}:[\w\d]{2}:[\w\d]{2}} $arpRes]
	return $arpList
}

proc deviceConnected {mac name notifyAll} {
	# do other stuff:
	# print time
	# sound an alarm, play music, robot voice
	# notify for high priority people
	# categorize high priority
	# ignore certain devices

	if {$name == "unknown" && !$notifyAll} {
		return 0
	}

	puts "$name $mac connected"

	return 0
}

proc deviceDisconnected {mac name notifyAll} {
	if {$name == "unknown" && !$notifyAll} {
		return 0
	}

	puts "$name $mac disconnected"
	return 0
}

main
