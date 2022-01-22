`default_nettype none
module mem_w #(parameter DW = 8, AW = 4)
   (input wire [AW-1:0]   in_addr,
    input wire [DW-1:0]   in_dat,
    input wire 	          clk, we,
    output logic [DW-1:0] out_data);

   var logic [DW-1:0] mem [0:(1 << AW)-1];

   always_ff @(posedge clk) begin
      if(we) mem[in_addr] <= in_dat;
   end
   assign out_data = ~we ? mem[in_addr] : 'z;
endmodule // mem_w

module mini_up
  (input wire clk,
   input wire rstn,
   input wire start,
   output wire [7:0] mem_dat);

   typedef enum logic [1:0] {idle, load_mem, exec, stop} states_t;
   states_t ps, ns;
   logic [7:0] counter_ps, counter_ns;
   logic we_ctrl;

   // Instantiate mem
   mem_w #(.DW(8), .AW(8))
   prog
     (.in_addr(counter_ps),
      .in_dat(counter_ps),
      .clk(clk),
      .we(we_ctrl),
      .out_data(mem_dat));

   always_ff @(posedge clk) begin
      if(!rstn) begin
	 ps <= idle;
	 counter_ps <= '0;
      end
      else begin
	 ps <= ns;
	 counter_ps <= counter_ns;
      end
   end

   always_comb begin
      ns = ps;
      counter_ns = counter_ps;
      unique case(ps)
	idle: if(start) ns = load_mem;
	load_mem: begin
	   if(!(&(counter_ps))) begin
	      counter_ns = counter_ps + 1'b1;
	      ns = load_mem;
	   end
	   else ns = exec;
	end
	exec: begin
	   if(|(counter_ps)) begin
	      counter_ns = counter_ps - 1'b1;
	      ns = exec;
	   end
	   else ns = stop;
	end
	stop: ns = idle;
      endcase // unique case (ps)
   end // always_comb

   assign we_ctrl = (ps == load_mem) ? 1'b1 : 1'b0;

   default clocking fpv_clk @(posedge clk); endclocking
   default disable iff(!rstn);

   ap_no_deadlock: assert property(ps == idle && start |=> s_eventually ps == stop);
   ap_write:       assert property(ps == load_mem |=> prog.mem[$past(counter_ps)] == $past(counter_ps));
endmodule // mini_up

module top(input wire clk, rstn,
	   input wire start,
	   output logic [7:0] fo_data,
	   output logic co_fault);

   logic [7:0] main_data, follower_data;

   mini_up main (clk, rstn, start, main_data);
   mini_up follower(clk, rstn, start, follower_data);

   assign co_fault = main.ps == 2'b10 && (main_data != follower_data);
   assign fo_data  = main_data;
   
   default clocking fpv_clk @(posedge clk); endclocking
   default disable iff(!rstn);
   ap_main: assert property(nexttime not co_fault);
   
endmodule // top
`default_nettype wire

