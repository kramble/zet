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
	return $retval
}

proc send_loop {fp} {
	set at_eof 0

	while {$at_eof == 0} {
		if { 1 } {
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
	set at_eof 0

	while {$at_eof == 0} {
		if { 1 } {
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

proc send_sector {fp} {
	# number of packets to send for 512 bytes (including pre and postamble)
	set count 19
	set at_eof 0

	while {$at_eof == 0} {
		
		if { $count > 0 } {

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
			incr count -1
		} else {
			# kludge, just stop after count reaches 0
			set at_eof 1
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
	puts -nonewline "\nCommand (a,b,d,h,k,q,r,s,v,x)? "
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
		push_data_to_fpga "00000000"
	}
	if { $cmd == "r" } {
		# Run (removes reset)
		puts "Sending RUN"
		# Top bit is active-low reset
		push_data_to_fpga "80000000"
	}
	if { $cmd == "v" } {
		puts "Sending TOGGLE VIDEO"
		# NB this assumes we are in RUN mode (no point otherwise)
		push_data_to_fpga "c0003300"
		push_data_to_fpga "800033ee"
	}
	if { $cmd == "b" } {
		puts "Booting with flash emulation"
		# Check for boot
		set noboot 0
		set adata [get_bulkaddr_from_fpga]
		# First byte is always 00, check the second byte (00 at boot, 01 or greater for diskett I/O)
		set adata2 [string range $adata 2 3]
		# puts "adata $adata 2nd byte $adata2"
		if {$adata2 == "00"} {
			# Send bios
			puts "BOOT - Sending BIOS"
			# Send Reset then Run
			push_data_to_fpga "00000000"
			push_data_to_fpga "80000000"
			# Allow time for sdram init (not sure if needed, but may fix boot hangs)
			after 500
			# CARE HARD CODED FILENAME
			set fdfilename "biosfd_v04.zbd"
			puts "sending $fdfilename"
			set fp [open "$fdfilename" r]
			fconfigure $fp -translation binary
			send_bulk $fp
			# bulk address should now be 00010000 for first sector of DOS boot
			set adata [get_bulkaddr_from_fpga]
			while {$adata != "00010000"} {
				# Happens always 0000FF7F ... probably due to delay before loading DOS boot sector
				puts "waiting for DOS boot request, address $adata"
				# puts "sleep 50"
				after 50
				set adata [get_bulkaddr_from_fpga]
			}
			puts "Sending TOGGLE VIDEO"
			push_data_to_fpga "c0003300"
			push_data_to_fpga "800033ee"
		} else  {
			puts "NO BOOT, entering flash emulation loop"
			set noboot 1
		}
		# We've loaded the bios if necessary (alternatively could have entered this command post-boot)
		# now loop processing sector requests (first after boot will be 00010000
		# TODO may need to implement a request counter in case of duplicates, use reserved BPD eg 0000:04AC to 04EF

		set prevsector -1
		set fdlooping 1
		while {$fdlooping==1} {
			# read adata repeatedly until it settles (sync to clock domain)
			# puts "fdloop"
			set adata_prev $adata
			set adata [get_bulkaddr_from_fpga]
			# puts "prev adata $adata_prev current $adata"
			while {$adata != $adata_prev} {
				# puts "waiting: prev adata $adata_prev current $adata"
				after 5
				set adata_prev $adata
				set adata [get_bulkaddr_from_fpga]
			}
			# process request
			set sectorhex [string range $adata 2 5]
			# puts "sectorhex = $sectorhex"
			set sector [expr 0x$sectorhex - 256]
			if {$noboot==1} {
				# Prevent re-send of sector on restart
				set prevsector $sector
				set noboot 0
			}
			# puts "sector = $sector"
			if {$sector != $prevsector} {
				# set fdfilename "floppy_mos_v03.zpk"
				# set fdfilename "freedos.zpk"
				set fdfilename "dos6.22.zpk"
				puts "sending $fdfilename sector $sector"
				set fp [open "$fdfilename" r]
				fconfigure $fp -translation binary
				seek $fp [expr $sector * 1024]
				send_sector $fp
				set prevsector $sector
			}
			after 10
		}
		# End "b" command
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
