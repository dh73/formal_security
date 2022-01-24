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

# All the proofs will take some time as they need a lot of cycles before
# precondition is reached. Also, there are some liveness properties!
prove -bg -all;

# QED

