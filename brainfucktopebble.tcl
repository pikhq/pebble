#!/usr/bin/tclsh
proc rle {} {
	global line index
	set char [string index $line $index]
	set temp $char
	set i 0
	while {$char == $temp} {
		incr index
		set char [string index $line $index]
		incr i
	}
	incr index -1
	return $i
}
while {-1 != [gets stdin line]} {
	set index 0
	while {$index != [string length $line]} {
		set char [string index $line $index]
		set temp $char
		switch -- $char {
			+ {
				set i [rle]
				puts "add current $i"
			}
			- {
				set i [rle]
				puts "subtract current $i"
			}
			[ {
				puts "while current \{"
			}
			] {
				puts "\}"
			}
			. {
				puts "out current"
			}
			, {
				puts "in current"
			}
			> {
				set i [rle]
				puts "right $i"
			}
			< {
				set i [rle]
				puts "left $i"
			}
			default {
			}
		}
		incr index
	}
}
