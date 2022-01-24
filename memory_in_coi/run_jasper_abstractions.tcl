# Clear environment
clear -all;

# Elaborate the design
analyze -sv12 {memory_abstraction.sv};
analyze -sv12 {top.sv};
## The disable_auto_bbox will make the elab command to not cut the memory in the design
elaborate -top {top} -disable_auto_bbox;

# Define clocks and resets
clock clk -factor 1 -phase 1;
reset -expression {!(rstn)};

# Let's abstract counters so we reach the preconditions quickly.
abstract -counter follower.counter_ps;
abstract -counter main.counter_ps;

# But now that the counters are abstracted, we need to let the solver know
# that, when state machine leaves the load_memory state, both memories must
# have the same contents, otherwise we have a spurious CEX.
assume -name no_diff_counters {follower.counter_ps == main.counter_ps};
#assume -name missing {main.ps == load_mem && main.ns == exec |=> main.prog.mem == follower.prog.mem};
assume -name missing {main.ps == load_mem && main.ns == exec |=> main.prog.pkt_ps == follower.prog.pkt_ps};

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

# The complexity is reduced now.
prove -bg -all;

# QED

