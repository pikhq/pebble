namespace eval nooptimize {
	variable newcode
	variable slave

	# Passthrough creates a proc to pass through
	# a command to the next pass.
	proc Passthrough {name arglist} {
		set code "proc $name \{$arglist\} \{variable newcode;append newcode \"$name"
		foreach i $arglist {
			append code " \$[set i]"
		}
		append code "\\n\"\}"
		eval $code
	}

	# This binds our commands into the slave interpreter.
	proc binder {interp} {
		variable slave
		set slave $interp

		foreach i "[$slave aliases]" {
			$slave alias $i {}
		}
		foreach i {left right at @ set add subtract in out is0 isnot0 inline forceinline while set goto be0 lang sameval} {
			$slave alias $i ::nooptimize::$i
		}
		foreach i {while set} {
			$slave alias $i ::nooptimize::_$i
		}
		$slave alias \# \#
	}

	# While needs special treatment
	proc _while {var code {touches {}} {varlist {}}} {
		variable newcode
		variable slave
		
		append newcode "while $var \{\n"
		$slave eval $code
		append newcode "\}\n"
	}

	proc _set {var num} {
		variable newcode

		append newcode "set $var $num\n"
	}

	# set up passed through commands
	foreach {name args} {goto {var num} out {var} inline {args} forceinline {args} left {num} right {num} at {var} add {var num} subtract {var num} in {var} @ {var num}} {
		Passthrough $name $args
	}

	# Can't be passed through normally.
	proc lang {code} {
		variable newcode

		append newcode "lang \{$code\}\n"
	}

	# Remove commands from ::optimize
	proc is0 {args} {}
	proc isnot0 {args} {}
	proc be0 {args} {}
	proc sameval {vara varb} {}
}
