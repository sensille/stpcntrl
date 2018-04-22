`timescale 1ns / 1ps


//
// the step output will be held high for one cycle when a step
// should be generated. This add a pipeline stage.
// dir is the corresponding direction for the step. Be aware that
// dir probably has to be valid before step for the stepper driver.
//
module cntrl#(
	parameter WIDTH = 36
) (
	input clk,

	// FIFO interface
	input [WIDTH*2-1:0] rd_data,
	input rd_empty,
	output rd_en,

	// step/dir output
	output reg step = 0,	// set to high for one cycle when a step should be generated
	output reg dir = 0,	// corresponding dir for the step

	input start,

	// debug/status information
	output reg underflow = 0,
	output reg running = 0,
	output reg idle = 0
);


//
// velocity state machine
//
reg [WIDTH-1:0] cmd_cnt = 0;
reg [WIDTH-1:0] position = 0;
reg [WIDTH-1:0] velocity = 0;
reg [WIDTH-1:0] acceleration = 0;

// step calculation
wire do_step;
wire [WIDTH-1:0] new_position;
wire [WIDTH-1:0] new_velocity;

assign {do_step, new_position} = {1'b0, position} + {1'b0, velocity};
assign new_velocity = velocity + acceleration;
assign rd_en = (cmd_cnt == 0) && (running || start);

always @(posedge clk) begin
	if (cmd_cnt == 0 && !rd_empty && (start || running)) begin
		//
		// load new command
		//
		if (rd_data[WIDTH-1:0] == 0) begin
			idle <= 1;
			running <= 0;
		end else begin
			idle <= 0;
			running <= 1;
		end
		cmd_cnt <= rd_data[WIDTH-1:0];
		acceleration <= rd_data[WIDTH*2-1:WIDTH];
		underflow <= 0;
		// keep position and velocity
	end else if (cmd_cnt == 0 && !(idle || start)) begin
		//
		// cmd done, but no new command available
		//
		cmd_cnt <= 0;
		position <= 0;
		velocity <= 0;
		acceleration <= 0;
		running <= 0;
		step <= 0;
		dir <= 0;
		underflow <= 1;
		idle <= 0;
	end else begin
		//
		// cmd still running
		//
		if (!idle)
			cmd_cnt <= cmd_cnt - 1;
		velocity <= new_velocity;
		position <= new_position;
	end
	if (do_step ^ velocity[WIDTH-1]) begin
		step <= 1;
		dir <= velocity[WIDTH-1];
	end else begin
		step <= 0;
	end
end

endmodule
