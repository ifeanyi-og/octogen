# scripts/create_project.tcl
# Run from repo root:
#   vivado -mode batch -source scripts/create_project.tcl
# or in GUI Tcl console:
#   cd <repo_root>
#   source scripts/create_project.tcl

set PROJ_NAME "octogen"
set PROJ_DIR  [file normalize "./vivado"]
set PART      "xc7k325tffg676-2"
set TOP       "octogen_top"

set RTL_DIR   [file normalize "./src/rtl"]
set XDC_DIR   [file normalize "./constraints"]

file mkdir $PROJ_DIR
create_project $PROJ_NAME $PROJ_DIR -part $PART -force

# ---- Add RTL sources (recursive) ----
package require fileutil

set rtl_files {}
set patterns {*.v *.sv *.vh *.vhd *.vhdl}

foreach p $patterns {
  set found [fileutil::findByPattern $RTL_DIR -glob $p]
  if {[llength $found] > 0} {
    set rtl_files [concat $rtl_files $found]
  }
}

# De-duplicate
set rtl_files [lsort -unique $rtl_files]
if {[llength $rtl_files] == 0} {
  puts "ERROR: No RTL files found under $RTL_DIR"
  exit 1
}
add_files -norecurse $rtl_files
set_property top $TOP [current_fileset]

# Add constraints
set xdc_files [glob -nocomplain -directory $XDC_DIR -types f *.xdc]
if {[llength $xdc_files] > 0} {
  add_files -fileset constrs_1 -norecurse $xdc_files
}

# ---- Add Block Designs (.bd) - RECURSIVE ----
set BD_DIR [file normalize "./src/bd"]
set bd_files [glob -nocomplain -directory $BD_DIR -types f *.bd]

# Also search subdirectories
if {[file isdirectory $BD_DIR]} {
  foreach subdir [glob -nocomplain -directory $BD_DIR -type d *] {
    set more_bd [glob -nocomplain -directory $subdir -types f *.bd]
    set bd_files [concat $bd_files $more_bd]
  }
}

if {[llength $bd_files] > 0} {
  add_files -norecurse $bd_files
  puts "INFO: Added [llength $bd_files] block design(s): $bd_files"
} else {
  puts "WARNING: No .bd files found in $BD_DIR"
}

# ---- Add IP cores (XCI files) - RECURSIVE ----
set IP_DIR [file normalize "./src/ip"]
set xci_files [glob -nocomplain -directory $IP_DIR -types f *.xci]

# Also search subdirectories
if {[file isdirectory $IP_DIR]} {
  foreach subdir [glob -nocomplain -directory $IP_DIR -type d *] {
    set more_xci [glob -nocomplain -directory $subdir -types f *.xci]
    set xci_files [concat $xci_files $more_xci]
  }
}

if {[llength $xci_files] > 0} {
  foreach xci $xci_files {
    read_ip $xci
  }
  puts "INFO: Added [llength $xci_files] IP core(s): $xci_files"
  
  # Regenerate all IP
  puts "INFO: Regenerating IP outputs..."
  set all_ips [get_ips *]
  foreach ip $all_ips {
    generate_target all [get_files ${ip}.xci]
    export_ip_user_files -of_objects [get_files ${ip}.xci] -no_script -sync -force -quiet
  }
  puts "INFO: IP regeneration complete"
} else {
  puts "WARNING: No .xci files found in $IP_DIR"
}


update_compile_order -fileset sources_1
puts "Created: $PROJ_DIR/$PROJ_NAME.xpr"
