namespace eval brainfuck {
	set location 0
	set memmap(current) 0
	set newcode ""
	variable slave

	# Bind our calls into the slave interpreter.
	proc binder {interp} {
		variable slave
		set slave $interp

		foreach i "[$slave aliases]" {
			$slave alias $i {}
		}
		foreach i {left right at @ add subtract in out forceinline goto set} {
			$slave alias $i ::brainfuck::$i
		}
		foreach i {while set} {
			$slave alias $i ::brainfuck::_$i
		}
	}

	# Go to a variable's location in the Brainfuck memory.
	proc goto {var {dist default}} {
		variable location
		variable memmap

		if {$dist eq "default"} {
			set dist 0
		}
		set num [expr {$memmap($var) + $dist}]
		if {$num < $location} {
			left [expr {$location - $num}]
		} elseif {$num > $location} {
			right [expr {$num - $location}]
		}
		@ current $location
	}

	# Add $num to variable $var.
	proc add {var num} {
		variable newcode

		goto $var
		for {set n $num} {$n != 0} {incr n -1} {
			append newcode "+"
		}
	}

	# Subtract $num from variable $var
	proc subtract {var num} {
		variable newcode

		goto $var
		for {set n $num} {$n != 0} {incr n -1} {
			append newcode "-"
		}
	}

	# Go right $num in BF memory.
	proc right {num} {
		variable newcode
		variable location

		for {set i $num} {$i != 0} {incr i -1} {
			append newcode ">"
			incr location
		}
		@ current $location
	}

	# Go left $num in BF memory.
	proc left {num} {
		variable newcode
		variable location

		for {set i $num} {$i != 0} {incr i -1} {
			append newcode "<"
			incr location -1
		}
		@ current $location
	}

	# After "right" and "left", tell the compiler we're at $var.
	proc at {var} {
		variable location
		variable slave
		variable memmap

		set location $memmap($var)
		@ current $location
	}

	# Set $var to $num in the BF memory.
	proc _set {var num} {
		variable newcode

		foreach i $var {
			goto $i
			append newcode "\[-]"
			if {$num > 0} {
				add $i $num
			} elseif {$num < 0} {
				subtract $i [regsub -- - $num ""]
			}
		}
	}

	# A while loop in BF.
	proc _while {var code} {
		variable newcode
		variable slave

		goto $var
		append newcode \[
		$slave eval $code
		goto $var
		append newcode \]
	}

	# Declare a variable at location $num.
	proc @ {var num} {
		variable memmap

		set memmap($var) $num
	}

	# Output $var.
	proc out {var} {
		variable newcode

		goto $var
		append newcode .
	}

	# Input to $var.
	proc in {var} {
		variable newcode

		goto $var
		append newcode ,
	}

	# Put $args into the resulting code untouched.
	proc forceinline {args} {
		variable newcode

		if {[string index $args 0] eq "\{"} {
			set args [string range $args 1 end]
		}
		if {[string index $args end] eq "\}"} {
			set args [string range $args 0 end-1]
		}
		append newcode $args \n
	}
}
