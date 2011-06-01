namespace eval macro {
	variable memmap
	variable newcode
	variable lastloc 0
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

	# Helper to Map.
	proc Sub {to var from} {
		upvar $var in
		set in [regsub -all -- $to $in $from]
	}

	# Maps special chars in languages.
	proc Map {var} {
		if {$::params(lang) eq "interpret"} {}
		# May be incomplete.
		if {$::params(lang) eq "c"} {
			Sub "a" var "aa"
			Sub "_" var "__"
			Sub "@" var "@@"
			Sub {\$} var {\$\$}
			Sub "," var ",,"
			Sub {\.} var {\.\.}
			Sub {\?} var {\?\?}

			Sub "!" var "_"
			Sub "-" var "@"
			Sub {\+} var {\$}
			Sub "=" var ","
			Sub {\*} var "."
			Sub "/" var {\?}
			Sub "b" var "a"
		}
		if {$::params(lang) eq "brainfuck"} {
			Sub "!" var "!!"
			Sub {\@} var {\@\@}
			Sub {\#} var {\#\#}
			Sub {\$} var {\$\$}
			Sub "%" var "%%"
			Sub {\^} var {\^\^}
			Sub "&" var "&&"
			Sub {\*} var {\*\*}

			Sub {\+} var "!"
			Sub "-" var {\@}
			Sub {\.} var {\#}
			Sub "," var {\$}
			Sub {\>} var "%"
			Sub {\<} var {\^}
			Sub {\[} var "&"
			Sub {\]} var {\*}
		}
		return $var
	}

	# binder, when given an interpreter, binds the procs
	# in ::macro into it. This allows us to implement BFM
	# rather effectively.
	proc binder {interp} {
		variable slave
		set slave $interp

		foreach i "[$slave eval info commands]" {
			$slave hide $i
		}
		foreach i {left right at @ set add subtract in out is0 isnot0 inline forceinline goto macro if0 if-1 be0 lastloc lang sameval stringout} {
			$slave alias $i ::macro::$i
		}
		foreach i {while set source string eval} {
			$slave alias $i ::macro::_$i
		}
		$slave alias \# \#
		@ current 0
		variable lastloc
		set lastloc 0
	}

	# Everything below this comment will be bound into the slave interpreter.

	# The following procedures are entirely handled in the preprocessing pass.
	eval {
		# macro creates macros; these macros are called as procs within
		# the slave interpreter (where all BFM code is executed).
		proc macro {name input output temp code} {
			variable slave

			# This foreach block is a bit ugly; needs to be fixed sometime.
			# I especially don't like the regexps involved.
			foreach i "$input $output $temp" {
				set code [regsub -all " [lindex $i 0] " $code " \$[lindex $i 0] "]
				set code [regsub -all " [lindex $i 0]\n" $code " \$[lindex $i 0]\n"]
			}
			set string "inline $name:; $code;inline \"\""
			# This, while messy, works right.
			# Surely there must be a better way of doing this?
			if {$input eq ""} {
				set argstring ""
			} elseif {($output eq "") && ($temp eq "")} {
				set argstring "$input"
			} elseif {$output eq ""} {
				set argstring "$input {: :} $temp"
			} elseif {$temp eq ""} {
				set argstring "$input {> >} $output"
			} else {
				set argstring "$input {> >} $output {: :} $temp"
			}
			$slave invokehidden proc $name "$argstring" $string
		}
		
		# Evalutes $args within the context of the BFM slave interpreter.
		# Provided in BFM to allow for conditionals beyond the builtin "while".
		proc _eval {args} {
			variable slave

			if {[string index $args 0] eq "\{"} {
				set args [string range $args 1 end]
			}
			if {[string index $args end] eq "\}"} {
				set args [string range $args 0 end-1]
			}
			$slave eval $args
		}
		
		# Loads a file into the BFM interpreter.
		# ^ indicates the stdlib directory.
		proc _source {file} {
			global stdlib
			global params
			variable slave
			set regfile_std [file join [regsub -all {\^} $file $stdlib]]
			set regfile_lang [file join [regsub -all {\^} $file "[file join $stdlib $params(lang)][file separator]"]]

			if {[file exists $regfile_lang] && ($params(O) == 2)} {
				set file $regfile_lang
			} elseif {[file exists $regfile_std]} {
				set file $regfile_std
			} else {
				puts stderr "Error: Can't find file $file."
				exit 1
			}

			set fid [open $file]
			$slave eval [read $fid]
			close $fid
		}
		
		# Implements C-style strings.
		# Requires "source ^stdcons.bfm" in BFM to use properly.
		proc _string {stringname string {start default}} {
			variable lastloc

			if {$start eq "default"} {
				if {$lastloc == 0} {
					set start 1
				} else {
					set start $lastloc
				}
			}
			if {$start == 0} {
				puts stderr "Warning: Strings can't start at location 0."
				puts stderr "Changing to location 1."
			}
			@ [set stringname]0 $start
			for {set i 0} {$i != [string length $string]} {incr i} {
				@ $stringname[expr {$i + 1}]
				interp eval slave cons[scan [string index $string $i] %c] $stringname$i : $stringname[expr {$i + 1}]
			}
			@ [set stringname]end [expr {$i + $start}]
		}

		# Output a string somewhat efficiently, using two cells.
		proc stringout {string {: :} temp1 temp2} {
			set $string [subst -novariables -nocommands $string]
			interp eval slave set $temp1 0
			set cell_value 0
			for {set i 0} {$i != [string length $string]} {incr i} {
				if {$cell_value > [scan [string index $string $i] %c]} {
					set diff [expr {$cell_value - [scan [string index $string $i] %c]}]
					interp eval slave subcons$diff $temp1 : $temp2
				} else {
					set diff [expr {[scan [string index $string $i] %c] - $cell_value}]
					interp eval slave addcons$diff $temp1 : $temp2
				}
				interp eval slave out $temp1
				set cell_value [scan [string index $string $i] %c]
			}
		}

		# Conditional compilation, part one.
		proc if0 {code} {
			global eof
			variable slave
			if {$eof == 0} {
				$slave eval $code
			}
		}
		
		# Conditional compilation, the sequel.
		proc if-1 {code} {
			global eof
			variable slave
			if {$eof == -1} {
				$slave eval $code
			}
		}

		# See last-assigned location.
		proc lastloc {} {
			variable lastloc

			puts stderr $lastloc
		}
	}

	# These are handled specially by the preprocessing pass before
	# being passed on through.
	eval {
		# @ automatically assigns memory locations.
		# This way, no other passes need to care.
		proc @ {var {num default}} {
			variable newcode
			variable lastloc
			variable memmap

			if {$num eq "default"} {
				set num $lastloc
			}
			append newcode "@ [Map $var] $num\n"
			set memmap($var) $num
			set lastloc [expr {$num + 1}]
		}
		
		# Implementation of "add", in the first pass.
		# Handles arbitrary numbers of arguments before $num.
		proc add {args} {
			variable newcode

			set args [regsub \{ $args ""]
			set args [regsub \} $args ""]
			set var [lrange $args 0 end-1]
			set num [lindex $args end]
			foreach i $var {
				append newcode "add [Map $i] $num\n"
			}
		}
		
		# Implementation of "subtract", in the first pass.
		# Handles arbitrary numbers of arguments before $num.
		proc subtract {args} {
			variable newcode

			set args [regsub \{ $args ""]
			set args [regsub \} $args ""]
			set var [lrange $args 0 end-1]
			set num [lindex $args end]
			foreach i $var {
				append newcode "subtract [Map $i] $num\n"
			}
		}
	}

	# The following are passed through without any special treatment.
	eval {
		# Just filtering "while" down through the passes.
		# Because a while block contains code to be executed,
		# it needs to be handled specially from normal passthrough procs.
		proc _while {var code {touches {}} {varlist {}}} {
			variable newcode
			variable slave

			append newcode "while [Map $var] \{\n"
			set code [$slave invokehidden subst -nobackslashes $code]
			$slave eval $code
			append newcode "\} $touches $varlist\n"
		}
		
		# Passes "set" calls down the stream.
		# Because the command starts with _, it
		# doesn't work with Passthrough right.
		proc _set {args} {
			variable newcode

			set args [regsub \{ $args ""]
			set args [regsub \} $args ""]
			set var [lrange $args 0 end-1]
			set num [lindex $args end]
			foreach i $var {
				append newcode "set [Map $i] $num\n"
			}
		}
		
		# goto doesn't work via Passthrough because of the pesky
		# default argument.
		proc goto {var {num default}} {
			variable newcode

			append newcode "goto [Map $var] $num\n"
		}
		
		# The following procs need to be out of the Passthrough loop
		# Map must be run.
		proc at {var} {
			variable newcode

			append newcode "at [Map $var]\n"
		}

		proc in {var} {
			variable newcode

			append newcode "in [Map $var]\n"
		}

		proc out {var} {
			variable newcode

			append newcode "out [Map $var]\n"
		}

		proc lang {code} {
			variable newcode
			variable slave
			variable memmap

			set code [$slave invokehidden subst -nobackslashes -nocommands $code]
			foreach i [array names memmap] {
				set code [regsub -all $i $code [Map $i]]
			}
			append newcode "lang \{$code\}\n"
		}

		# Create all that we've not created.
		foreach {name args} {right {num} left {num} is0 {args} isnot0 {args} inline {args}
			forceinline {args} be0 {args} sameval {vara varb}} {
			Passthrough $name $args
		}
	}
}