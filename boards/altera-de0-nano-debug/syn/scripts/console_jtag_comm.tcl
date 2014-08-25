# JTAG Communication Functions
# Abstracts the JTAG interface away to a few interface functions

# ACKNOWLEDGEMENT (Zet):
# Based on https://github.com/progranism/Open-Source-FPGA-Bitcoin-Miner

# User API Functions
# These should be generic and be the same no matter what the underlying FPGA is.
# Use these to interact with the FPGA.
# TODO: These are designed to assume a single FPGA. Re-design to handle multiple FPGAs, assigning
# an arbitrary ID to each FPGA.


# Initialize the FPGA
proc fpga_init {} {
	global fpga_name

	set fpga [find_the_fpga]

	if {$fpga == -1} {
		return -1
	}

	set hardware_name [lindex $fpga 0]
	set device_name [lindex $fpga 1]

	start_insystem_source_probe -hardware_name $hardware_name -device_name $device_name

	set fpga_name "$hardware_name $device_name"

	return 0
}

# Console control
proc push_data_to_fpga {data} {
	write_instance "ZETC" $data
}

# Bulk data (flash)
proc push_bulkdata_to_fpga {data} {
	write_instance "ZETB" $data
}

# Readback status (currenty = LEDs)
proc get_data_from_fpga {} {
	set rdata [read_instance ZETR]
	return $rdata
}

proc get_bulkaddr_from_fpga {} {
	set adata [read_instance ZETA]
	return $adata
}

# Return the FPGA's "name", which could be anything but is hopefully helpful (to the user) in
# indentifying which FPGA the software is talking to.
proc get_fpga_name {} {
	global fpga_name
	return $fpga_name
}

###
# Internal FPGA/JTAG APIs are below
# These should not be accessed outside of this script
###################################

set fpga_instances [dict create]
set fpga_last_nonce 0
set fpga_name "Unknown"

# Search the specified FPGA device for all Sources and Probes
proc find_instances {hardware_name device_name} {
	global fpga_instances

	set fpga_instances [dict create]

	if {[catch {

		foreach instance [get_insystem_source_probe_instance_info -hardware_name $hardware_name -device_name $device_name] {
			dict set fpga_instances [lindex $instance 3] [lindex $instance 0]
		}

	} exc]} {
		puts stderr "DEV-REMOVE: Error in find_instances: $exc"
		set fpga_instances [dict create]
	}
}

proc write_instance {name value} {
	global fpga_instances
	write_source_data -instance_index [dict get $fpga_instances $name] -value_in_hex -value $value
}

proc read_instance {name} {
	global fpga_instances
	return [read_probe_data -value_in_hex -instance_index [dict get $fpga_instances $name]]
}

proc instance_exists {name} {
	global fpga_instances
	puts "fpga_instances $fpga_instances"
	
	return [dict exists $fpga_instances $name]
}

# Try to find an FPGA on the JTAG chain that has FpgaProg firmware loaded into it.
# TODO: Return multiple FPGAs if more than one are found.
proc find_the_fpga {} {
	set hardware_names [get_hardware_names]

	if {[llength $hardware_names] == 0} {
		puts stderr "ERROR: There are no Altera devices currently connected."
		puts stderr "Please connect an Altera FPGA and re-run this script.\n"
		return -1
	}

	foreach hardware_name $hardware_names {
		puts "HW NAME $hardware_name"
		if {[catch { set device_names [get_device_names -hardware_name $hardware_name] } exc]} {
			#puts stderr "DEV-REMOVE: Error on get_device_names: $exc"
			continue
		}

		foreach device_name $device_names {
		puts "DV NAME $device_name"
			if { [check_if_fpga_is_correct $hardware_name $device_name] } {
				return [list $hardware_name $device_name]
			}
		}
	}

	puts stderr "ERROR: There are no Altera FPGAs with ZET firmware loaded on them."
	puts stderr "Please program your FPGA with correct firmware and re-run this script.\n"

	return -1
}


# Check if the specified FPGA has FpgaProg firmware loaded (ie virtual wire named ZETC)
proc check_if_fpga_is_correct {hardware_name device_name} {
	find_instances $hardware_name $device_name

	if {[instance_exists ZETC]} {
		return 1
	}

	return 0
}
