##
# console.tcl ... based on fpgaprog.tcl
#
# Copyright (c) 2011 fpgaminer@bitcoin-mining.com
#
# ACKNOWLEDGEMENT (Zet):
# Based on https://github.com/progranism/Open-Source-FPGA-Bitcoin-Miner
#
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
# 
##

source console_jtag_comm.tcl

proc say_line {msg} {
	set t [clock format [clock seconds] -format "%D %T"]
	puts "\[$t\] $msg"
}

proc say_error {msg} {
	set t [clock format [clock seconds] -format "%D %T"]
	puts stderr "\[$t\] $msg"
}

proc hexincr {val} {
	# Increment a 4 digit hex value
	set hexval [format 0x%s $val]
	set newval [expr {$hexval + 1}]
	set retval [format %04x $newval]
	# puts "newval=$newval"
	# puts "retval=$retval"
	return $retval
}

proc send_loop {fp} {
	set begin_time [clock clicks -milliseconds]
	set at_eof 0

	while {$at_eof == 0} {
		# Send a packet of data every few milliseconds (TODO may want to just send as fast as possible)
		
		set now [clock clicks -milliseconds]
		# Comment out the wait to see how fast it will go at full speed (not much faster actually)
		# STUPID interpreter attempts to parse COMMENTS, what IDIOT thought of that? So we need a closing brace!
		# if { [expr {$now - $begin_time}] >= 2 } { } # added 2nd brace to avoid parse error IN COMMENT !!!!!!
		if { 1 } {

			set dt [expr {$now - $begin_time}]
			set begin_time $now

			if {$dt == 0} {
				set dt 1
			}

			# Push 32 bits (4 bytes) each time, vis { command, word_address, high_byte, low_byte}
			# command= { ~RESET, VIDEO, X, X, X, X, X, WR }
			# NB set ~RESET=0 during I/O so as to halt the CPU and avoid contention
			# The data is read in raw form, so needs to be pre-formatted with address/control signals
			# EXCEPT When loading bios.rom we need the CPU running, so do not assert reset here.
			# ... all controls are handled by the raw data file, so nothing to do here.
			
			set bytes 4
			set data ""
			
			while {$bytes > 0} {
				if [eof $fp] {
					set at_eof 1
					# This does not work, so tweak below (at ADDENDUM)
					set inData 0
				} else {
					set inData [read $fp 1]
				}
				binary scan $inData c val
				set val [expr {$val & 0xFF}]
				# Tweak (see above)
				if {$at_eof == 1} {
					set val 0
				}
				set data [format %s%02x $data $val]
				incr bytes -1
			}

			if { $at_eof == 0 } {
				# puts "send $data"
				push_data_to_fpga $data
			}
		}
	}

	return -1
}

proc send_bulk {fp} {
	set begin_time [clock clicks -milliseconds]
	set at_eof 0

	while {$at_eof == 0} {
		# Send a packet of data every few milliseconds (TODO may want to just send as fast as possible)
		
		set now [clock clicks -milliseconds]
		# Comment out the wait to see how fast it will go at full speed (not much faster actually)
		# STUPID interpreter attempts to parse COMMENTS, what IDIOT thought of that? So we need a closing brace!
		# if { [expr {$now - $begin_time}] >= 2 } { } # added 2nd brace to avoid parse error IN COMMENT !!!!!!
		if { 1 } {

			set dt [expr {$now - $begin_time}]
			set begin_time $now

			if {$dt == 0} {
				set dt 1
			}

			# Push 256 bits (32 bytes) each time, vis flags + 31 data bytes
			# Flags = top bit strobe and lowest 5 bits is byte count (0 is the idle state)
			# TODO use 2 strobe bits and alternate for double the speed
			# The data is read in raw form, so needs to be pre-formatted with control signals
			# The flash controller latches data on strobe, then decrements count each time
			# a byte is read, passing { count, byte } as the 16 bit word back to caller.
			# Data is read by flash controller in sequence from low byte to high
			# NB This uses a different vw channel, hence push_bulkdata_to_fpga
			
			set bytes 32
			set data ""
			
			while {$bytes > 0} {
				if [eof $fp] {
					set at_eof 1
					# This does not work, so tweak below (at ADDENDUM)
					set inData 0
				} else {
					set inData [read $fp 1]
				}
				binary scan $inData c val
				set val [expr {$val & 0xFF}]
				# Tweak (see above)
				if {$at_eof == 1} {
					set val 0
				}
				set data [format %s%02x $data $val]
				incr bytes -1
			}

			if { $at_eof == 0 } {
				# puts "send $data"
				push_bulkdata_to_fpga $data
			}
		}
	}

	return -1
}

proc get_selected_list_item {lst idx} {
	# Convert to integer
	if [catch { set idx [expr {int($idx)}] }] {
		set idx -1
	}

	if {$idx < 0 || $idx >= [llength $lst]} {
		set len [llength $lst]
		puts "Invalid number. Please enter a number from 0 to $len"
		exit
	}

	return [lindex $lst $idx]
}

proc get_sendfile {} {
set mem_files [glob *.zet]
set id 0

foreach mem_file $mem_files {
	puts "$id) $mem_file"
	incr id
}

if {[llength $mem_files] == 0} {
	puts "I could not find any zet files in the local directory. Quitting..."
	exit
}

puts -nonewline "\nWhich zet file would you like to use? "
gets stdin selected_mem_id
puts ""

set mem_name [get_selected_list_item $mem_files $selected_mem_id]

puts "Selected mem file: $mem_name\n\n\n"

return $mem_name
}

# END get_sendfile

proc get_bulkfile {} {
set mem_files [glob *.zbd]
set id 0

foreach mem_file $mem_files {
	puts "$id) $mem_file"
	incr id
}

if {[llength $mem_files] == 0} {
	puts "I could not find any zbd files in the local directory. Quitting..."
	exit
}

puts -nonewline "\nWhich zbd file would you like to use? "
gets stdin selected_mem_id
puts ""

set mem_name [get_selected_list_item $mem_files $selected_mem_id]

puts "Selected mem file: $mem_name\n\n\n"

return $mem_name
}

# END get_bulkfile

# =====================
# MAIN body starts here
# =====================

puts " --- ZET CONSOLE Tcl Script --- \n\n"

# COMMENT OUT for testing ...
if {1} {

puts "Looking for and preparing FPGAs...\n"
if {[fpga_init] == -1} {
	puts stderr "No FPGAs found."
	puts "\n\n --- Shutting Down --- \n\n"
	exit
}

set fpga_name [get_fpga_name]
puts "FPGA Found: $fpga_name\n\n"

}
# END if {0}

set stop 0

while {$stop==0} {
	puts -nonewline "\nCommand (a,d,h,k,q,r,s,v,x)? "
	gets stdin cmd
	puts ""
	if { $cmd == "q" } {
		# Quit
		set stop 1
	}
	if { $cmd == "x" } {
		# eXit
		set stop 1
	}
	if { $cmd == "s" } {
		# Send data to bootrom (256 bytes max)
		set mem_name [get_sendfile]
		set fp [open $mem_name r]
		fconfigure $fp -translation binary
		send_loop $fp
	}
	if { $cmd == "k" } {
		set mem_name [get_bulkfile]
		set fp [open $mem_name r]
		fconfigure $fp -translation binary
		send_bulk $fp
	}
	if { $cmd == "h" } {
		# Halt
		puts "Sending HALT (asserts reset)"
		# Top bit is active-low reset
		# push_data_to_fpga "00000000"
		
		# low bytes are just for test 4a17 = "halt"
		push_data_to_fpga "00004a17"
	}
	if { $cmd == "r" } {
		# Run (removes reset)
		puts "Sending RUN"
		# Top bit is active-low reset
		# push_data_to_fpga "80000000"
		
		# low bytes are just for test 6060 = "gogo"
		push_data_to_fpga "80006060"
	}
	if { $cmd == "v" } {
		puts "Sending TOGGLE VIDEO"
		# NB this assumes we are in RUN mode (no point otherwise)
		push_data_to_fpga "c0003300"
		push_data_to_fpga "800033ee"
	}
	if { $cmd == "disabled_p" } {
		puts "Sending BOOT WAIT (use before b itself)"
		# Start by sending reset
		push_data_to_fpga "00000000"
	
		# Change boot vector to jump to itself at fff0 - so we can change other code
		push_data_to_fpga "0178f0ea"
		push_data_to_fpga "00000000"
	}
	if { $cmd == "disabled_b" } {
		# Boot - simple test, now using the s function instead
		# NB will need to return to "run" mode in order to see results on display (simple test sequencer)
		puts "Sending BOOT"
		# Start by sending reset
		push_data_to_fpga "00000000"

		# This is { command, word_address, high_byte, low_byte} ie backwards when reading machine code instructions
		# See entry.asm for SDRAM_POST, execution starts at fff0 (word addr 0x78) via instruction "ea 55 ff"
		# which jumps to address ff55 ie word address 0x2a (TODO check exactly since it's not aligned to a word).

		# For Test1 - Write first few rom addresses
		# push_data_to_fpga "01001234"
		# push_data_to_fpga "00000000"
		# push_data_to_fpga "01015678"
		# push_data_to_fpga "00000000"
		# push_data_to_fpga "0102abcd"
		# push_data_to_fpga "00000000"
		
		# (No longer necessary since I've fixed the run/halt logic...)
		# Change boot vector to jump to itself at fff0 - works, PC is scanning FFFx
		push_data_to_fpga "0178f0ea"
		push_data_to_fpga "00000000"
		
		# Write NOPs to SDRAM_POST (since I'm not sure about alignment), then out to leds port and loop via boot addr
		# HMMM, OUT ax takes 8 bit address, so how to access f100..f103 ?? Aha, neex to use dx for 16 bit port address
		# nop; nop; nop; nop	90 90 90 90
		push_data_to_fpga "01299090"
		push_data_to_fpga "00000000"
		push_data_to_fpga "012a9090"
		push_data_to_fpga "00000000"
		# mov ax, 6745			b8 45 67 - NB UNEXPECTEDLY 7 gets displayed via ledg_[7:4], expected 5, is the bus reversed?
		# mov dx, f100			ba 01 f1	port f101
		push_data_to_fpga "012b45b8"
		push_data_to_fpga "00000000"
		push_data_to_fpga "012cba67"
		push_data_to_fpga "00000000"
		push_data_to_fpga "012df101"
		push_data_to_fpga "00000000"

		# out dx, ax 			ef
		# jmp 00fff0			ea f0 ff 00
		push_data_to_fpga "012eeaef"
		push_data_to_fpga "00000000"
		push_data_to_fpga "012ffff0"
		push_data_to_fpga "00000000"
		push_data_to_fpga "01300000"
		push_data_to_fpga "00000000"
		
		# Change boot vector to jump to itself at ff55
		push_data_to_fpga "017855ea"
		push_data_to_fpga "00000000"
	}
	# Readback leds_
	if { $cmd == "d" } {
		set rdata [get_data_from_fpga]
		puts "GPIO LEDS = $rdata"
	}
	# Readback bulk address (TODO implement disk I/O)
	if { $cmd == "a" } {
		set adata [get_bulkaddr_from_fpga]
		puts "BULK ADDR = $adata"
	}
}

# TODO test if it's open before closing, but safe just to comment it out
# close $fp
puts "\n\n --- Shutting Down --- \n\n"
