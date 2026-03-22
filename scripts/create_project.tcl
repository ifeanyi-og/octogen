# scripts/create_project.tcl
# Run from repo root:
# vivado -mode batch -source scripts/create_project.tcl

# -------------------------
# Config
# -------------------------
set PROJ_NAME "octogen"
set PROJ_DIR  [file normalize "./vivado"]
set PART      "xc7k325tffg676-2"
set TOP       "octogen_top"

set RTL_DIR   [file normalize "./src/rtl"]
set TB_DIR    [file normalize "./src/tb"]
set XDC_DIR   [file normalize "./constraints"]
set BD_DIR    [file normalize "./src/bd"]
set IP_DIR    [file normalize "./src/ip"]

set MEM_SRC_DIR [file normalize "./mem_init"]
set MEM_DST_DIR [file normalize "$PROJ_DIR/mem_init"]

# -------------------------
# Create project
# -------------------------
file mkdir $PROJ_DIR
create_project $PROJ_NAME $PROJ_DIR -part $PART -force

set_property ip_output_repo [file normalize "$PROJ_DIR/ip_output_repo"] [current_project]
set_property ip_cache_permissions {read write} [current_project]

if {[catch {get_property board_part [current_project]}]} {
  # ignore
} else {
  set_property board_part {} [current_project]
}

# -------------------------
# Copy COE files
# -------------------------
file mkdir $MEM_DST_DIR

set coe_files [glob -nocomplain -directory $MEM_SRC_DIR -types f *.coe]
if {[llength $coe_files] == 0} {
  puts "ERROR: No .coe files found in $MEM_SRC_DIR"
  exit 1
}

foreach f $coe_files {
  file copy -force $f $MEM_DST_DIR
}

puts "INFO: Copied [llength $coe_files] .coe files"

# -------------------------
# Add RTL
# -------------------------
package require fileutil

set rtl_files {}
foreach p {*.v *.sv *.vh *.vhd *.vhdl} {
  set found [fileutil::findByPattern $RTL_DIR -glob $p]
  if {[llength $found] > 0} {
    set rtl_files [concat $rtl_files $found]
  }
}
set rtl_files [lsort -unique $rtl_files]

if {[llength $rtl_files] == 0} {
  puts "ERROR: No RTL files found"
  exit 1
}

add_files -norecurse $rtl_files
set_property top $TOP [current_fileset]

# -------------------------
# Add constraints
# -------------------------
set xdc_files [glob -nocomplain -directory $XDC_DIR -types f *.xdc]
if {[llength $xdc_files] > 0} {
  add_files -fileset constrs_1 -norecurse $xdc_files
}

# -------------------------
# Add IP (safe)
# -------------------------
set ip_files {}
if {[file exists $IP_DIR]} {
  set ip_files [fileutil::findByPattern $IP_DIR -glob *.xci]
  set ip_files [lsort -unique $ip_files]
}

if {[llength $ip_files] > 0} {

  # Avoid duplicate add
  set existing [get_files *.xci]
  set to_add {}

  foreach f $ip_files {
    if {[lsearch -exact $existing $f] < 0} {
      lappend to_add $f
    }
  }

  if {[llength $to_add] > 0} {
    add_files -norecurse $to_add
  }

  read_ip $ip_files
  update_ip_catalog

  set ips [get_ips *]

  # -------------------------
  # Fix COE paths (robust)
  # -------------------------
  foreach ip $ips {

    # Check if parameter exists
    if {[catch {get_property CONFIG.Coe_File $ip} coe]} {
      continue
    }

    # Skip disabled / empty
    if {$coe eq "" || $coe eq "no_coe_file_loaded"} {
      continue
    }

    set fname [file tail $coe]
    set new_path [file normalize "$MEM_DST_DIR/$fname"]

    puts "INFO: Fixing COE for $ip → $new_path"

    set_property CONFIG.Coe_File $new_path $ip
  }

  # -------------------------
  # Upgrade + Generate
  # -------------------------
  if {[llength $ips] > 0} {
    upgrade_ip $ips
    generate_target all $ips
    export_ip_user_files -of_objects $ips -no_script -sync -force -quiet
  }

  puts "INFO: Processed [llength $ips] IPs"

} else {
  puts "INFO: No IP found"
}

# -------------------------
# Add Block Designs
# -------------------------
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
}

# -------------------------
# Add testbenches
# -------------------------
set tb_files {}
if {[file exists $TB_DIR]} {
  foreach p {*.v *.sv *.vh *.vhd *.vhdl} {
    set found [fileutil::findByPattern $TB_DIR -glob $p]
    if {[llength $found] > 0} {
      set tb_files [concat $tb_files $found]
    }
  }
  set tb_files [lsort -unique $tb_files]
}

if {[llength $tb_files] > 0} {
  add_files -fileset sim_1 -norecurse $tb_files
}

# -------------------------
# Finalize
# -------------------------
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

puts "SUCCESS: Project created at $PROJ_DIR/$PROJ_NAME.xpr"

