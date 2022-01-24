# Clear environment
clear -all;

# FSV startup command
check_fsv -init;

# Elaborate the design
analyze -sv12 {memory_abstraction.sv};
analyze -sv12 {top.sv};

## The disable_auto_bbox will make the elab command to not cut the memory in the design
# elaborate -top {top} -disable_auto_bbox -bbox_i main.prog -bbox_i follower.prog
elaborate -top {top} -disable_auto_bbox;

# Define clocks and resets
clock clk -factor 1 -phase 1;
reset -expression {~rstn} {~top_bad_machine.rstn};

# Disable assertions as they're used for FPV only
assert -disable -regexp {.*}

# FSV settings
set_fsv_clock_cycle_time 100ns
set_fsv_strobe_optimization on
set_fsv_classification_scheme diagnostic
set_fsv_generate_detectability on
set_fsv_generate_always_detected on
set_fsv_generate_propagated_always_detected on
#set_fsv_max_faults_per_task 500
set_fsv_generate_copy_env on
set_fsv_proof_sanity_check on

#check_fsv -abstract -bbox_mod
check_fsv -abstract -instance main.prog 
check_fsv -abstract -instance follower.prog

# Lists for faults
set main_flops [get_design_info -instance main -list flop]

# Specify faults
check_fsv -fault -add $main_flops -type SEU -time_window 1:$

# Specify strobes
check_fsv -strobe -add [get_design_info -list output -silent] -functional
check_fsv -strobe -remove -node co_fault -functional
check_fsv -strobe -add co_fault -checker -checker_mode assert

# structural FSV analysis
check_fsv -structural

# Abstractions goes here === 
# Let's help CO_SANITY_CHECK proof and the rest to converge
abstract -counter follower.counter_ps -env;
abstract -counter main.counter_ps -env;
assume -name no_diff_counters {follower.counter_ps == main.counter_ps};

# Kind of inductive to speed up the proofs even more.
# First we get the list of flops in both the main core
set main_flops [get_design_info -instance main -list flop -silent];
# and the follower core
set follower_flops [get_design_info -instance follower -list flop -silent];
# Now, the value that the solver chooses for the flops must
# be equal to both main and follower:
foreach main $main_flops follower $follower_flops {
     puts "assume -name helper_$main \{$follower == $main\}"
     eval assume \{$follower == $main\}
}

abstract -init_value $main_flops;
abstract -init_value $follower_flops;

# Whatever applies to top, applies to bad_machine
assume -name bad_machine_counter_0 {top_bad_machine.main.counter_ps == main.counter_ps};
assume -name bad_machine_counter_1 {top_bad_machine.follower.counter_ps == top_bad_machine.main.counter_ps};
# end abstractions ===

# generate FSV properties
check_fsv -generate

# prove FSV properties
check_fsv -prove 

# Report FSV results
check_fsv -report -class dangerous
check_fsv -report -force -text fsv.rpt

# QED

