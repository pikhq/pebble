#!/usr/bin/env tclsh

if 0 {
Practical Esoteric Brainfuck-Based Language, Eh?
PEBBLE is both a compiler and a language, designed to compile to Brainfuck.
Copyright (C) 2007 Josiah Worcester

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License along
with this program; if not, write to the Free Software Foundation, Inc.,
51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
}

package require cmdline

set prefix [file dirname $argv0]
source [file join $prefix macro.tcl]
source [file join $prefix optimize.tcl]
source [file join $prefix nooptimize.tcl]
source [file join $prefix strip.tcl]
source [file join $prefix nostrip.tcl]
source [file join $prefix brainfuck.tcl]
source [file join $prefix interp.tcl]
source [file join $prefix c.tcl]

interp create -safe slave
set options {
	{f.arg "-" "Input file"}
	{O.arg "1" "Optimize"}
	{o.arg "-" "Output file"}
	{g "Disable stripping of output"}
	{e.arg 0 "Specify EOF type"}
	{i.arg "$prefix/stdlib" "Change location of stdlib"}
	{lang.arg "brainfuck" "Specify language to target. \[brainfuck, c, interpret]"}
}
set usage ": $argv0 \[options] ...\noptions:"
if {[catch {array set params [::cmdline::getoptions argv $options $usage]}]} {
	puts stderr [::cmdline::usage $options $usage]
	exit
}

if {$params(e)==0} {
	set eof 0
} elseif {$params(e)==-1} {
	set eof -1
} else {
	puts stderr "Invalid argument to -e."
}

if {![string compare $params(o) -]} {
	set ofid stdout
} else {
	set ofid [open $params(o) w]
}

if {![string compare $params(f) -]} {
	set ifid stdin
} else {
	set ifid [open $params(f)]
}

set stdlib "[subst [set params(i)]]/"

# Preprocessing. . .
::macro::binder slave
slave eval [read $ifid]
set last macro

if {$params(O) != 0} {
	# Optimize. . .
	::optimize::binder slave
	slave eval [set ::[set last]::newcode]
	set last optimize
} else {
	# Don't optimize. . .
	::nooptimize::binder slave
	slave eval [set ::[set last]::newcode]
	set last nooptimize
}

if {$params(g)} {
	# Add comments. . .
	::nostrip::binder slave
	slave eval [set ::[set last]::newcode]
	set last nostrip
} else {
	# Don't add comments. . .
	::strip::binder slave
	slave eval [set ::[set last]::newcode]
	set last strip
}

if {$params(lang) eq "interpret"} {
	# Interpretation
	::interpret::binder slave
	slave eval [set ::[set last]::newcode]
} elseif {$params(lang) eq "brainfuck"} {
	# End compilation. . .
	::brainfuck::binder slave
	slave eval [set ::[set last]::newcode]
	puts $ofid $::brainfuck::newcode
} elseif {$params(lang) eq "c"} {
	::c::binder slave
	slave eval [set ::[set last]::newcode]
	puts $ofid $::c::newcode
	puts $ofid \}
} else {
	puts stderr "'$params(lang)' is not a supported target language."
	exit
}
