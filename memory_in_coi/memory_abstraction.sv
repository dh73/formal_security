`default_nettype none
`ifndef _MEMORY_PKG_
 `define _MEMORY_PKG_
package memory_pkg;
   typedef enum logic [0:0] {ASYNC_READ, SYNC_READ} read_type_t;
endpackage // memory_pkg
`endif

module memory_abstraction import memory_pkg::*;
  #(parameter int unsigned DATA_WIDTH  = 32,
    parameter int unsigned ADDR_WIDTH  =  8,
    parameter int unsigned NUM_SYMBOLS =  4,
    parameter read_type_t  MEM_TYPE    = ASYNC_READ)
   (input wire wr_clk, 
    input wire rd_clk,
    input wire write_en,
    input wire [DATA_WIDTH-1:0] write_data,
    input wire [ADDR_WIDTH-1:0] write_addr,
    input wire [ADDR_WIDTH-1:0] read_addr,
    output logic [DATA_WIDTH-1:0] read_data);

   // Define an uninterpreted function (non-deterministic LUT)
   typedef struct packed {
      logic active;
      logic [ADDR_WIDTH-1:0] addr;
      logic [DATA_WIDTH-1:0] data;
   } abstract_t;
   abstract_t pkt_ps [0:NUM_SYMBOLS];
   abstract_t pkt_ns [0:NUM_SYMBOLS];
   
   logic [DATA_WIDTH-1:0] selected_data;
   
   always_comb begin
      abstract_t t;
      pkt_ns = pkt_ps;
      selected_data = '0;
      
      // Get default values
      t = '{active: write_en, 
            addr:   write_addr, 
            data:   write_data};

      for(int i = 0; i < NUM_SYMBOLS; i++) begin
         if(t.active) begin: write_data
	    pkt_ns[i] = t;
	    t = pkt_ps[i];
         end
      end
      
      for(int i = NUM_SYMBOLS-1; i >= 0; i--) begin: remove_data
	 t = pkt_ns[i];
	 if(!write_en) begin
	    // read operation expecting stored data
	    if(t.active) begin
	 	if(read_addr == t.addr) begin
	          t.active = 1'b0;
	          selected_data = t.data;
	    	end
	    	// read operation other cases
	    	else begin
	      		selected_data = pkt_ns[NUM_SYMBOLS].data;
	    	end
	    end
	    pkt_ns[i] = t;
	 end // if (!write_en)
      end // block: remove_data
   end // always_comb
   
   always_ff @(posedge wr_clk) pkt_ps = pkt_ns;

   // Output selection
   generate
      if(MEM_TYPE == ASYNC_READ) begin: async_out
	 assign read_data = selected_data;
      end
      else if(MEM_TYPE == SYNC_READ) begin
	 always_ff @(posedge rd_clk) read_data <= selected_data;
      end
   endgenerate
endmodule // memory_abstraction
`default_nettype wire     

module dummy_testbench import memory_pkg::*;
  #(parameter int unsigned DATA_WIDTH  = 32,
    parameter int unsigned ADDR_WIDTH  =  8,
    parameter int unsigned NUM_SYMBOLS =  4,
    parameter read_type_t  MEM_TYPE    = ASYNC_READ)
   (input wire wr_clk, 
    input wire rd_clk,
    input wire write_en,
    input wire [DATA_WIDTH-1:0] write_data,
    input wire [ADDR_WIDTH-1:0] write_addr,
    input wire [ADDR_WIDTH-1:0] read_addr,
    input logic [DATA_WIDTH-1:0] read_data);

   default clocking fpv_clk @(posedge wr_clk); endclocking
   
   sequence wr_1;
      !write_en
      ##1 write_data == 'hdeadbeef ##0
	  write_en ##1
          !write_en [*4] ##1 1'b1;
   endsequence // wr_1
   cvr0: cover property(wr_1);

   sequence wr_1_rd_1;
      !write_en ##1 
       write_data == 'hdeadbeef &&
       write_addr == 'ha &&
       write_en ##1
      !write_en &&
       read_addr == 'ha ##1 1'b1;
   endsequence // wr_1_rd_1
   cvr2: cover property(wr_1_rd_1);
endmodule // dummy_testbench
bind memory_abstraction dummy_testbench props (.*);

