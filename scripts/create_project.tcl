# scripts/create_project.tcl
# Run from repo root:
#   vivado -mode batch -source scripts/create_project.tcl

set PROJ_NAME "octogen"
set PROJ_DIR  [file normalize "./vivado"]
set PART      "xc7k325tffg676-2"
set TOP       "octogen_top"

set RTL_DIR   [file normalize "./src/rtl"]
set TB_DIR    [file normalize "./src/tb"]
set XDC_DIR   [file normalize "./constraints"]
set BD_DIR    [file normalize "./src/bd"]
set IP_DIR    [file normalize "./src/ip"]

# --- Create project ---
file mkdir $PROJ_DIR
create_project $PROJ_NAME $PROJ_DIR -part $PART -force

# Ensure this project is PART-based (not BOARD-based)
if {[catch {get_property board_part [current_project]} bp] == 0} {
  set_property board_part {} [current_project]
}

# ---- Copy .coe init files into project dir (must exist before IP is imported) ----
set MEM_SRC_DIR [file normalize "./mem_init"]
set MEM_DST_DIR [file normalize "$PROJ_DIR/mem_init"]
file mkdir $MEM_DST_DIR

set coe_files [glob -nocomplain -directory $MEM_SRC_DIR -types f *.coe]
if {[llength $coe_files] == 0} {
  puts "ERROR: No .coe files found in $MEM_SRC_DIR. Run the MATLAB generator first."
  exit 1
}
foreach f $coe_files {
  file copy -force $f $MEM_DST_DIR
}
puts "INFO: Copied [llength $coe_files] .coe file(s) to $MEM_DST_DIR"

# ---- Add RTL sources (recursive) ----
package require fileutil

set rtl_files {}
set patterns {*.v *.sv *.vh *.vhd *.vhdl}
foreach p $patterns {
  set found [fileutil::findByPattern $RTL_DIR -glob $p]
  if {[llength $found] > 0} { set rtl_files [concat $rtl_files $found] }
}

set rtl_files [lsort -unique $rtl_files]
if {[llength $rtl_files] == 0} {
  puts "ERROR: No RTL files found under $RTL_DIR"
  exit 1
}
add_files -norecurse $rtl_files
set_property top $TOP [current_fileset]

# ---- Add constraints ----
set xdc_files [glob -nocomplain -directory $XDC_DIR -types f *.xdc]
if {[llength $xdc_files] > 0} {
  add_files -fileset constrs_1 -norecurse $xdc_files
}

# ---- Import IP (.xci) BEFORE block designs ----
set ip_files {}
if {[file exists $IP_DIR]} {
  set ip_files [fileutil::findByPattern $IP_DIR -glob *.xci]
  set ip_files [lsort -unique $ip_files]
}

if {[llength $ip_files] > 0} {
  import_ip -files $ip_files
  puts "INFO: Imported [llength $ip_files] IP core(s) (.xci)"

  # Generate targets so batch mode has deterministic IP outputs
  set ips [get_ips -quiet]
  if {[llength $ips] > 0} {
    generate_target all $ips
    export_ip_user_files -of_objects $ips -no_script -sync -force -quiet
    puts "INFO: Generated output products for [llength $ips] IP(s)"
  }
} else {
  puts "INFO: No .xci IP files found under $IP_DIR"
}

# ---- Add Block Designs (.bd) ----
set bd_files {}
if {[file exists $BD_DIR]} {
  set bd_files [fileutil::findByPattern $BD_DIR -glob *.bd]
  set bd_files [lsort -unique $bd_files]
}

set existing_bd [get_files -quiet *.bd]
set to_add {}
foreach f $bd_files {
  if {[lsearch -exact $existing_bd $f] < 0} {
    lappend to_add $f
  }
}

if {[llength $to_add] > 0} {
  add_files -norecurse $to_add
  puts "INFO: Added [llength $to_add] block design(s)"
} else {
  puts "INFO: No new block designs to add"
}

# ---- Add Testbenches to Simulation Sources (sim_1) ----
set tb_files {}
if {[file exists $TB_DIR]} {
  foreach p $patterns {
    set found [fileutil::findByPattern $TB_DIR -glob $p]
    if {[llength $found] > 0} { set tb_files [concat $tb_files $found] }
  }
  set tb_files [lsort -unique $tb_files]
}

if {[llength $tb_files] > 0} {
  add_files -fileset sim_1 -norecurse $tb_files
  puts "INFO: Added [llength $tb_files] testbench file(s) to sim_1"
} else {
  puts "INFO: No testbench files found under $TB_DIR"
}

# Update compile order for both synthesis and simulation
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

puts "Created: $PROJ_DIR/$PROJ_NAME.xpr"
