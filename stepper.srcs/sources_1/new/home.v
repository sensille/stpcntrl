`timescale 1ns / 1ps


module home#(
	parameter POS_CNT_WIDTH	= 24
) (
	input clk,

	// step/dir input
	input step,
	input dir,

	// from sensor
	input home,

	// output
	output rev,

	// config interface
	input [POS_CNT_WIDTH-1:0] steps_per_rev,
	input home_request,

	output reg locked = 0
);

reg [POS_CNT_WIDTH-1:0] pos_counter = 0;
reg [POS_CNT_WIDTH-3:0] delay_home_req = 0;
reg searching_home = 0;

assign searching  = searching_home;
assign delaying = delay_home_req != 0;

//assign rev = pos_counter == 0;
assign rev = pos_counter[POS_CNT_WIDTH-1:6] == 0;


always @(posedge clk) begin
	if (home_request) begin
		if (home) begin
			// sensor currently asserted, wait for a quarter turn before
			// listening to sensor
			delay_home_req <= steps_per_rev[POS_CNT_WIDTH-1:2];
		end else begin
			delay_home_req <= 0;
		end
		searching_home <= 1;
		locked <= 0;
	end

	if (step) begin
		if (delay_home_req != 0) begin
			delay_home_req <= delay_home_req - 1;
		end else if (searching_home && home) begin
			pos_counter <= 0;
			searching_home <= 0;
			locked <= 1;
		end else if (dir) begin
			if (pos_counter == 0)
				pos_counter <= steps_per_rev - 1;
			else
				pos_counter <= pos_counter - 1;
		end else begin
			if (pos_counter == steps_per_rev - 1)
				pos_counter <= 0;
			else
				pos_counter <= pos_counter + 1;
		end
	end
end

endmodule
