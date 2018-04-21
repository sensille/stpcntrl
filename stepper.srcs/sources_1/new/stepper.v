`timescale 1ns / 1ps

module stepper(
	input	clk_50mhz,
	output	led_0,	// onboard
	output	led_1,	// bank 14, M12 (U7, pin 7)
	output	reg step = 0,	// bank 14, N14 (U7, pin 9)
	output	reg dir = 0,	// bank 14, P15 (U7, pin 11)
	input	sck,	// bank 14, N13 (U7, pin 8)
	input	sdi,	// bank 14, N16 (U7, pin 10)
	input	sen,	// bank 14, P16 (U7, pin 12)
	output	rev,
	input	home,

	output  debug1,
	output  debug2,
	output  debug3,
	output  debug4
);

wire clk;

clk u_clk(
	.clk_50mhz(clk_50mhz),
	.clk(clk)
);

//
// blinking LED
//
reg [21:0] cnt = 0;

assign led_0 = cnt[21];

always @(posedge clk)
	cnt <= cnt + 1;

// register for steps/revolution
reg [23:0] steps_per_rev = 24'd20;
reg home_request = 0;

// read side of fifo
wire rd_en;
wire [71:0] rd_data;
wire running;
wire underflow;

//
// serial interface with entry side FIFO
//
reg [79:0] spireg = 0;
wire wr_en;
wire rd_empty;
always @(posedge sck) begin
	spireg <= { spireg[78:0], sdi };
end

// sync sen into our clock domain
reg sen1;
reg sen2;
reg sen3;
reg sen4;

always @(posedge clk) begin
	sen1 <= sen;
	sen2 <= sen1;
	sen3 <= sen2;
	sen4 <= sen3;
end

wire cmd_valid = (sen3 == 1) && (sen4 == 0);
assign wr_en = cmd_valid && (spireg[7:0] == 8'h9a);
wire set_running = (cmd_valid && spireg[7:0] == 8'hb5);
wire set_rev_register = (cmd_valid && spireg[7:0] == 8'ha3);
wire set_home_request = (cmd_valid && spireg[7:0] == 8'h3b);
reg start;
always @(posedge clk) begin
	start <= set_running;
	home_request <= set_home_request;
	if (set_rev_register)
		steps_per_rev <= spireg[32:8];
end

fifo u_fifo(
	.clk(clk),

	// write side
	.din(spireg[79:8]),
	.wr_en(wr_en),
	.full(),

	// read side
	.dout(rd_data),
	.rd_en(rd_en),
	.empty(rd_empty)
);

wire do_step;
wire next_dir;
cntrl u_cntrl(
	.clk(clk),

	// fifo control
	.rd_data(rd_data),
	.rd_empty(rd_empty),
	.rd_en(rd_en),

	// step/dir
	.step(do_step),
	.dir(next_dir),

	.start(start),

	// debug/status information
	.underflow(underflow),
	.running(running)
);

assign led_1 = underflow;

//
// generate double edge step from do_step.
// output new dir always with the preceding clk
//
reg next_step = 0;
always @(posedge clk) begin
	next_step <= do_step;
	dir <= next_dir;
	if (next_step) begin
		step <= ~step;
	end
end

wire locked;

home u_home(
	.clk(clk),

	.step(do_step),
	.dir(next_dir),

	.home(home),
	.rev(rev),

	.steps_per_rev(steps_per_rev),
	.home_request(home_request),

	.locked(locked)
);

//
// route debug output
//
assign debug1 = 0; 		// yellow
assign debug2 = home;		// orange
assign debug3 = locked;		// red
assign debug4 = running;	// brown

endmodule
