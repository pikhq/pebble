package require struct
namespace eval optimize {
	::struct::stack ::optimize::clear
	::struct::stack ::optimize::save
	::struct::stack ::optimize::touches

	variable newcode
	variable slave
	set relative 0

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

	# This proc makes sure the compiler doesn't make unsafe assumptions in relative addressing.
	proc Unsafe {} {
		variable relative
		set tostack ""

		if {$relative} {
			for {set i [clear size];clear clear} {$i != 0} {incr i -1} {
				clear push ""
			}
		}
	}		

	# Returns 0 if the cell isn't clear.
	proc Cleared {var} {
		if {[string match "* $var *" [if {[clear size]} {clear peek}]]} {
			return 1
		} else {
			return 0
		}
	}

	# This binds our commands into the slave interpreter.
	proc binder {interp} {
		variable slave
		set slave $interp

		foreach i "[$slave aliases]" {
			$slave alias $i {}
		}
		foreach i {left right at @ set add subtract in out is0 isnot0 inline forceinline while set goto be0 lang sameval} {
			$slave alias $i ::optimize::$i
		}
		foreach i {while set} {
			$slave alias $i ::optimize::_$i
		}
		$slave alias \# \#
	}

	# The following commands aren't passed through.
	eval {
		# Append to the top of the clear-stack $args.
		proc is0 {args} {
			set args [regsub \{ $args ""]
			set args [regsub \} $args ""]
			foreach i $args {
				if {$i ne "current" && ![string match "* $i *" [expr {[touches size]?[touches peek]:{}}]]} {
					clear push "[if {[clear size]} {clear pop}] $i "
				}
			}
		}
		
		# Remove $args from everywhere in the clear-stack.
		proc isnot0 {args} {
			set args [regsub \{ $args ""]
			set args [regsub \} $args ""]
			foreach i $args {
				if {![string match "* $i *" [expr {[touches size]?[touches peek]:{}}]]} {
					for {set n [clear size]} {$n != 0} {incr n -1} {
						save push [clear pop]
					}
					for {set n [save size]} {$n != 0} {incr n -1} {
						clear push [regsub -all " $i " [save pop] ""]
					}
				}
			}
		}

		# Inform the programmer about the internal cleared status of a cell.
		proc be0 {args} {
			set args [regsub \{ $args ""]
			set args [regsub \} $args ""]
			foreach i $args {
				if {[string match "* $i *" [clear peek]]} {
					puts stderr "$i yes."
				} else {
					puts stderr "$i no."
				}
			}
			puts stderr [clear peek]
		}

		# If vara is 0, make varb 0. If vara isn't 0, make varb not 0.
		proc sameval {vara varb} {
			if {[string match "* $vara *" [clear peek]]} {
				is0 $varb
			} else {
				isnot0 $varb
			}
		}			
	}

	# The following commands are passed through, but handled specially.
	eval {
		# Manual "left" calls use relative addressing.
		proc left {num} {
			variable newcode
			variable relative

			if {$num != 0} {
				append newcode "left $num\n"
			}
			set relative 1
		}

		# Manual "right" calls use relative addressing.
		proc right {num} {
			variable newcode
			variable relative

			if {$num != 0} {
				append newcode "right $num\n"
			}
			set relative 1
		}

		# "at" calls end relative addressing.
		proc at {var} {
			variable newcode
			variable relative

			append newcode "at $var\n"
			set relative 0
		}

		# add makes a cell non-zero; is a non-safe operation in relative addressing.
		proc add {var num} {
			variable newcode

			isnot0 $var
			append newcode "add $var $num\n"
			Unsafe
		}

		# subtract makes a cell non-zero; is a non-safe operation in relative addressing.
		proc subtract {var num} {
			variable newcode

			isnot0 $var
			append newcode "subtract $var $num\n"
			Unsafe
		}

		# in makes a cell non-zero; is a non-safe operation in relative addressing.
		proc in {var} {
			variable newcode

			isnot0 $var
			append newcode "in $var\n"
			Unsafe
		}

		# Only pass a while loop through if it'll actually run.
		proc _while {var code {touches {}} {varlist {}}} {
			variable newcode
			variable slave

			append newcode "while $var \{\n"
			touches push $varlist
			clear push [if {[clear size]} {clear peek}]
			# set code [interp invokehidden slave subst $code]
			$slave eval $code
			clear pop
			touches pop
			is0 $var
			append newcode "\}\n"
		}

		# Only pass a set through if it'll run.
		proc _set {var num} {
			variable newcode

			Unsafe
			foreach i $var {
				if {![Cleared $var]} {
					append newcode "set $var 0\n"
				}
				is0 $i
				if {$num > 0} {
					add $i $num
				} elseif {$num < 0} {
					subtract $i [regsub -- - $num ""]
				}
			}
		}

		# New variables should be 0.
		proc @ {var num} {
			variable newcode

			append newcode "@ $var $num\n"
			is0 $var
		}

		# Can't be passed through normally.
		proc lang {code} {
			variable newcode

			append newcode "lang \{$code\}\n"
		}
	}

	# Raw passthrough commands.
	foreach {name args} {goto {var num} out {var} inline {args} forceinline {args}} {
		Passthrough $name $args
	}
}
