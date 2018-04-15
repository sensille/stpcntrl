`timescale 1ns / 1ps


module fifo #(
	parameter DATA_WIDTH = 72,
	parameter ADDR_WIDTH = 6
) (
	input clk,
	// write side
	input [DATA_WIDTH - 1 : 0] din,
	input wr_en,
	output full,
	// read side
	output [DATA_WIDTH - 1 : 0] dout,
	input rd_en,
	output empty
);

localparam ADDRS = 1 << ADDR_WIDTH;
reg [DATA_WIDTH - 1 : 0] ram[ADDRS - 1 : 0];

reg [ADDR_WIDTH - 1 : 0] rdptr = 0;
reg [ADDR_WIDTH - 1 : 0] wrptr = 0;

wire [ADDR_WIDTH - 1 : 0] next_rdptr = rdptr + 1;
wire [ADDR_WIDTH - 1 : 0] next_wrptr = wrptr + 1;

assign empty = wrptr == rdptr;
assign full = next_wrptr == rdptr;
assign dout = ram[rdptr];

always @(posedge clk) begin
	if (rd_en && !empty) begin
		rdptr <= next_rdptr;
	end
	if (wr_en && !full) begin
		ram[wrptr] <= din;
		wrptr <= next_wrptr;
	end
end

endmodule
