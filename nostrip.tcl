namespace eval nostrip {
	set newcode ""
	variable slave

	# Bind our procs into the slave interpreter.
	proc binder {interp} {
		variable slave
		set slave $interp

		foreach i "[$slave aliases]" {
			$slave alias $i {}
		}
		foreach i {left right at @ set add subtract in out inline forceinline goto is0 isnot0 be0 is isnot lang} {
			$slave alias $i ::nostrip::$i
		}
		foreach i {while set} {
			$slave alias $i ::nostrip::_$i
		}
	}

	# Add an appropriate comment for a call.
	proc Commenter {arg} {
		variable newcode

		append newcode "$arg\nforceinline \" $arg\"\n"
	}

	# While statements, as usual, must be handled specially.
	proc _while {var code} {
		variable newcode
		variable slave

		append newcode "forceinline \"while $var\"\n"
		append newcode "while $var \{\n"
		append newcode "forceinline {}\n"
		$slave eval $code
		append newcode "\}\n"
		append newcode "forceinline {}\n"
	}

	# _set must also be handled specially.
	proc _set {var num} {
		if {$num < 0} {
			Commenter "set $var 0"
			Commenter "subtract $var [regsub -all -- - $num ""]"
		} else {
			Commenter "set $var $num"
		}
	}

	# Convert to "forceinline".
	proc inline {args} {
		variable newcode

		append newcode "forceinline $args\n"
	}

	# goto must be handled specially.
	proc goto {var num} {
		if {$num eq "default"} {
			Commenter "goto $var 0"
		} else {
			Commenter "goto $var $num"
		}
	}

	# Only proc passed through untouched.
	proc forceinline {args} {
		variable newcode

		append newcode "forceinline $args\n"
	}

	# Normal handling of commenting calls.
	foreach {name arg} {left {num} right {num} at {var} @ {var num}
		 add {var num} subtract {var num} in {var} out {var} } {
		set code "proc $name \{$arg\} \{Commenter \"$name"
		foreach i $arg {
			append code " \$[set i]"
		}
		append code \"\}
		eval $code
	}

	# Can't be passed through normally, and doesn't need commenting.
	proc lang {code} {
		variable newcode

		append newcode "lang \{$code\}\n"
	}

	# Ignored procs
	proc is0 {var} {}
	proc isnot0 {var} {}
	proc be0 {args} {}
}
