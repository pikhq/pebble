namespace eval interpret {
	set location 0
	set memory(0) 0
	set memmap(current) 0
	variable slave

	# Takes BFM variable, returns value.
	proc Getval {var} {
		variable memory
		variable memmap

		return $memory($memmap($var))
	}

	# Makes a variable be mod 256.
	proc Modvar {var} {
		variable memory
		variable memmap

		set memory($memmap($var)) [expr {$memory($memmap($var))%256}]
	}

	# Bind our calls into the slave interpreter.
	proc binder {interp} {
		variable slave
		set slave $interp

		foreach i "[$slave aliases]" {
			$slave alias $i {}
		}
		foreach i {left right at @ add subtract in out forceinline goto lang} {
			$slave alias $i ::interpret::$i
		}
		foreach i {while set} {
			$slave alias $i ::interpret::_$i
		}
	}

	# Go to a variable's location in the BFM memory.
	proc goto {var {dist default}} {
		variable location
		variable memory
		variable memmap

		if {$dist eq "default"} {
			set dist 0
		}
		set location [expr {$memmap($var) + $dist}]
		@ current $location
		if {($dist!=0) && ([array get memory $location] eq "")} {
			set memory($location) 0
		}
	}

	# Add $num to variable $var.
	proc add {var num} {
		variable location
		variable memory

		goto $var
		incr memory($location) $num
		set memory($location) [expr {$memory($location)%256}]
	}

	# Subtract $num from variable $var
	proc subtract {var num} {
		variable location
		variable memory

		goto $var
		incr memory($location) -$num
		set memory($location) [expr {$memory($location)%256}]
	}

	# Go right $num in BFM memory.
	proc right {num} {
		variable memory
		variable location

		incr location $num
		@ current $location
		if {[array get memory $location] eq ""} {
			set memory($location) 0
		}
	}

	# Go left $num in BFM memory.
	proc left {num} {
		variable memory
		variable location

		incr location -$num
		@ current $location
		if {[array get memory $location] eq ""} {
			set memory($location) 0
		}
	}

	# Set $var to $num in the BFM memory.
	proc _set {var num} {
		variable memory
		variable location

		foreach i $var {
			goto $i
			set memory($location) $num
			if {$num != 0} {
			        isnot0 $i
			}
		}
	}

	# A while loop for BFM.
	proc _while {var code} {
		variable location
		variable memory
		variable slave

		goto $var
		while {$memory($location)} {
			$slave eval $code
			goto $var
		}
	}

	# Declare a variable at location $num.
	proc @ {var num} {
		variable memmap
		variable memory

		set memmap($var) $num
		if {[array get memory $num] eq ""} {
			set memory($num) 0
		}
	}

	# Output $var.
	proc out {var} {
		variable memory
		variable location

		goto $var
		puts -nonewline [format %c $memory($location)]
		flush stdout
	}

	# Input to $var.
	proc in {var} {
		variable memory
		variable location
		global eof

		goto $var
		set memory($location) [scan [read stdin 1] %c]
		if {$memory($location) eq ""} {
			set memory($location) $eof
		}
	}

	# Interpreter-specific code execution.
	proc lang {code} {
		variable memory
		variable memmap

		eval $code
	}

	# To be ignored; useful for compilers, not interpreters.
	proc at {var} {}
	proc forceinline {args} {}
}
