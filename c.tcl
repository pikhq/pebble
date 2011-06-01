namespace eval c {
	set location 0
	set newcode "\#include <stdio.h>
\#include <stdlib.h>
unsigned char b\[30000],*current;
int main() \{
"
	set memmap(current) ""
	variable slave

	# Bind our calls into the slave interpreter.
	proc binder {interp} {
		variable slave
		set slave $interp

		foreach i "[$slave aliases]" {
			$slave alias $i {}
		}
		foreach i {left right at @ add subtract in out forceinline goto lang} {
			$slave alias $i ::c::$i
		}
		foreach i {while set} {
			$slave alias $i ::c::_$i
		}
	}

	# Go to a variable's location in memory.
	proc goto {var {dist default}} {
		variable location
		variable slave
		variable memmap

		if {$dist eq "default"} {
			set dist 0
		}
		set num [expr {$memmap($var)+$dist}]
		if {$num < $location} {
			left [expr {$location-$num}]
		} elseif {$num > $location} {
			right [expr {$num-$location}]
		}
	}

	# Go left in memory
	proc left {num} {
		variable location
		variable newcode
		variable memmap

		incr location -$num
		append newcode "current-=$num;\n"
		set memmap(current) $location
	}

	# Go right in memory
	proc right {num} {
		variable location
		variable newcode
		variable memmap

		incr location $num
		append newcode "current+=$num;\n"
		set memmap(current) $location
	}

	# Tell compiler where it is in memory.
	proc at {var} {
		goto $var
	}

	# Declare a variable.
	proc @ {var addr} {
		variable newcode
		variable memmap
		variable slave

		if {[array get memmap $var] eq ""} {
			append newcode "unsigned char *"
		}
		set memmap($var) $addr
		$slave invokehidden set $var $addr
		append newcode "[set var]=b+[set addr];\n"
	}

	# Add num to var.
	proc add {var num} {
		variable memmap
		variable newcode

		goto $var
		append newcode "*[set var]+=[set num];\n"
	}

	# Subtract num from var.
	proc subtract {var num} {
		variable memmap
		variable newcode

		goto $var
		append newcode "*[set var]-=[set num];\n"
	}

	# Input from stdin into var.
	proc in {var} {
		variable memmap
		variable newcode
		global eof

		goto $var
		append newcode "*[set var]=getchar();"
		if {$eof==0} {
			append newcode "if(feof(stdin))*[set var]=0;"
		}
		append newcode \n
	}

	# Output to stdout from var.
	proc out {var} {
		variable memmap
		variable newcode
		
		goto $var
		append newcode "putchar(*[set var]);\n"
	}

	# Forced inline comment
	# While brainfuck.tcl just puts the code out into the source,
	# forceinline code *should* be a comment; anything relying on
	# brainfuck.tcl's behavior is non-compliant with the BFM spec.
	proc forceinline {args} {
		variable newcode

		append newcode "/* $args */\n"
	}

	# While loop; $code needs to be evaled in $slave so it actually
	# gets compiled.
	proc _while {var code} {
		variable newcode
		variable slave
		variable memmap

		goto $var
		append newcode "while(*[set var])\{\n"
		$slave eval $code
		goto $var
		append newcode "\}\n"
	}

	# Sets var to num.
	proc _set {var num} {
		variable newcode
		variable memmap

		goto $var
		append newcode "*[set var]=[set num];\n"
	}

	# C-specific code to put into newcode.
	proc lang {code} {
		variable newcode

		append newcode $code
	}
}
