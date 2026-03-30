# scripts/create_project.tcl
# Run from repo root:
#   vivado -mode batch -source scripts/create_project.tcl

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

# keep all generated artifacts under vivado/
set LOCAL_IP_REPO      [file normalize "$PROJ_DIR/ip_output_repo"]
set LOCAL_IP_USER_DIR  [file normalize "$PROJ_DIR/ip_user_files"]
set LOCAL_IP_CACHE_DIR [file normalize "$PROJ_DIR/ip_cache"]
set LOCAL_GEN_DIR      [file normalize "$PROJ_DIR/gen"]

# -------------------------
# Helpers
# -------------------------
proc collect_files_recursive {base_dir patterns} {
  set out {}
  if {![file exists $base_dir]} {
    return $out
  }
  package require fileutil
  foreach p $patterns {
    set found [fileutil::findByPattern $base_dir -glob $p]
    if {[llength $found] > 0} {
      set out [concat $out $found]
    }
  }
  return [lsort -unique $out]
}

proc add_new_files {args} {
  # usage:
  #   add_new_files $files
  #   add_new_files -fileset sim_1 $files
  if {[llength $args] == 1} {
    set files [lindex $args 0]
    set existing [get_files -quiet]
    set to_add {}
    foreach f $files {
      if {[lsearch -exact $existing $f] < 0} {
        lappend to_add $f
      }
    }
    if {[llength $to_add] > 0} {
      add_files -norecurse $to_add
    }
  } elseif {[llength $args] == 3} {
    set opt     [lindex $args 0]
    set fileset [lindex $args 1]
    set files   [lindex $args 2]
    if {$opt ne "-fileset"} {
      error "add_new_files: expected -fileset"
    }
    set existing [get_files -quiet -of_objects [get_filesets $fileset]]
    set to_add {}
    foreach f $files {
      if {[lsearch -exact $existing $f] < 0} {
        lappend to_add $f
      }
    }
    if {[llength $to_add] > 0} {
      add_files -fileset $fileset -norecurse $to_add
    }
  } else {
    error "add_new_files: wrong number of args"
  }
}

# -------------------------
# Create project
# -------------------------
file mkdir $PROJ_DIR
file mkdir $MEM_DST_DIR
file mkdir $LOCAL_IP_REPO
file mkdir $LOCAL_IP_USER_DIR
file mkdir $LOCAL_IP_CACHE_DIR
file mkdir $LOCAL_GEN_DIR

create_project $PROJ_NAME $PROJ_DIR -part $PART -force

# Part-based project only
if {[catch {get_property board_part [current_project]}]} {
  # ignore
} else {
  set_property board_part {} [current_project]
}

# Force generated artifacts into vivado/
set proj_obj [current_project]

# general project directories
set_property ip_output_repo         $LOCAL_IP_REPO      $proj_obj
set_property ip_cache_permissions   {read write}        $proj_obj
catch {set_property ip_user_files_dir $LOCAL_IP_USER_DIR $proj_obj}
catch {set_property ip_cache_location  $LOCAL_IP_CACHE_DIR $proj_obj}
catch {set_property sim.ipstatic.source_dir $LOCAL_GEN_DIR [current_fileset -simset]}
catch {set_property generate_ip_upgrade_log true $proj_obj}

# This is the critical part for stopping root-level *.gen/*.cache spill
set proj_file [get_files -quiet "$PROJ_DIR/$PROJ_NAME.xpr"]
if {$proj_file ne ""} {
  catch {set_property parent.project_path $PROJ_DIR $proj_file}
}

# -------------------------
# Copy COE files into vivado/mem_init
# -------------------------
set coe_files [glob -nocomplain -directory $MEM_SRC_DIR -types f *.coe]
if {[llength $coe_files] == 0} {
  puts "ERROR: No .coe files found in $MEM_SRC_DIR"
  exit 1
}

foreach f $coe_files {
  file copy -force $f $MEM_DST_DIR
}
puts "INFO: Copied [llength $coe_files] .coe file(s) to $MEM_DST_DIR"

# -------------------------
# Add RTL
# -------------------------
set rtl_files [collect_files_recursive $RTL_DIR {*.v *.sv *.vh *.vhd *.vhdl}]
if {[llength $rtl_files] == 0} {
  puts "ERROR: No RTL files found under $RTL_DIR"
  exit 1
}
add_new_files $rtl_files
set_property top $TOP [current_fileset]

# -------------------------
# Add constraints
# -------------------------
set xdc_files [glob -nocomplain -directory $XDC_DIR -types f *.xdc]
if {[llength $xdc_files] > 0} {
  add_new_files -fileset constrs_1 $xdc_files
}

# -------------------------
# Add IP (.xci) as referenced sources
# canonical source remains src/ip
# generated outputs go under vivado/
# -------------------------
set ip_files [collect_files_recursive $IP_DIR {*.xci}]

if {[llength $ip_files] > 0} {
  add_new_files $ip_files

  # load referenced IPs
  read_ip $ip_files
  update_ip_catalog

  set ips [get_ips -quiet *]

  foreach ip $ips {
    # Try Coe_File only for IPs that actually expose it
    if {[catch {get_property CONFIG.Coe_File $ip} coe]} {
      continue
    }

    # skip disabled / blank placeholders
    if {$coe eq "" || $coe eq "no_coe_file_loaded"} {
      continue
    }

    set fname [file tail $coe]
    set new_path [file normalize "$MEM_DST_DIR/$fname"]

    if {![file exists $new_path]} {
      puts "ERROR: Required COE file for IP '$ip' not found: $new_path"
      exit 1
    }

    puts "INFO: Setting COE for $ip -> $new_path"
    catch {set_property CONFIG.Coe_File $new_path $ip}
  }

  # Upgrade only if needed
  set upgrade_targets {}
  foreach ip $ips {
    if {![catch {set status [get_property IS_LOCKED $ip]}]} {
      lappend upgrade_targets $ip
    } else {
      lappend upgrade_targets $ip
    }
  }

  if {[llength $upgrade_targets] > 0} {
    catch {upgrade_ip $upgrade_targets}
  }

  # Generate all output products
  if {[llength $ips] > 0} {
    generate_target all $ips

    # Export into vivado/ip_user_files, not repo root
    export_ip_user_files \
      -of_objects $ips \
      -ip_user_files_dir $LOCAL_IP_USER_DIR \
      -ipstatic_source_dir $LOCAL_GEN_DIR \
      -no_script -sync -force -quiet

    # Create synth/sim support products
    catch {create_ip_run $ips}
  }

  puts "INFO: Processed [llength $ips] IP(s)"
} else {
  puts "INFO: No .xci IP files found under $IP_DIR"
}

# -------------------------
# Add Block Designs
# -------------------------
set bd_files [collect_files_recursive $BD_DIR {*.bd}]
if {[llength $bd_files] > 0} {
  add_new_files $bd_files
  puts "INFO: Added [llength $bd_files] block design file(s)"
} else {
  puts "INFO: No block designs found under $BD_DIR"
}

# -------------------------
# Add testbenches to sim_1
# -------------------------
set tb_files [collect_files_recursive $TB_DIR {*.v *.sv *.vh *.vhd *.vhdl}]
if {[llength $tb_files] > 0} {
  add_new_files -fileset sim_1 $tb_files
  puts "INFO: Added [llength $tb_files] testbench file(s) to sim_1"
} else {
  puts "INFO: No testbench files found under $TB_DIR"
}

# -------------------------
# Finalize
# -------------------------
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

# save project so Vivado writes paths under vivado/
save_project_as $PROJ_NAME $PROJ_DIR -force

puts "SUCCESS: Project created at $PROJ_DIR/$PROJ_NAME.xpr"
puts "INFO: Canonical IP sources remain in $IP_DIR"
puts "INFO: Generated IP artifacts are directed under $PROJ_DIR"

