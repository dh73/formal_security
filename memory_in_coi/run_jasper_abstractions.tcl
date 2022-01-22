# Clear environment
clear -all;

# Elaborate the design
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
assume -name missing {main.ps == load_mem && main.ns == exec |=> main.prog.mem == follower.prog.mem};

# The complexity is reduced now.
prove -bg -all;

# QED

