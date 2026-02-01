# scripts/create_project.tcl
# Run from repo root:
#   vivado -mode batch -source scripts/create_project.tcl
# or in GUI Tcl console:
#   cd <repo_root>
#   source scripts/create_project.tcl

set PROJ_NAME "octogen"
set PROJ_DIR  [file normalize "./vivado"]
set PART      "xc7k325tffg676-2";
set TOP       "octogen_top";

set RTL_DIR   [file normalize "./src/rtl"]
set XDC_DIR   [file normalize "./constraints"]

file mkdir $PROJ_DIR
create_project $PROJ_NAME $PROJ_DIR -part $PART -force

# ---- Add RTL sources (recursive) ----
# fileutil::find is the most robust way in Vivado Tcl
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

# ---- Add Block Designs (.bd) ----
set BD_DIR [file normalize "./src/bd"]

set bd_files [fileutil::findByPattern $BD_DIR -glob *.bd]
set bd_files [lsort -unique $bd_files]

if {[llength $bd_files] > 0} {
  add_files -norecurse $bd_files
  puts "INFO: Added [llength $bd_files] block design(s)"
} else {
  puts "INFO: No block designs found under $BD_DIR"
}

if {[llength $bd_files] > 0} {
  add_files -norecurse $bd_files
  puts "INFO: Added [llength $bd_files] block design(s)"
}

update_compile_order -fileset sources_1
puts "Created: $PROJ_DIR/$PROJ_NAME.xpr"