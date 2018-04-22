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
	output	reg sdo = 0,
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
reg [20:0] home_tolerance = 20'd5;
reg home_request = 0;

// read side of fifo
wire rd_en;
wire [71:0] rd_data;
wire running;
wire underflow;

//
// serial interface with entry side FIFO
//
wire [15:0] status;
wire wr_en;
wire rd_empty;

// sync sck to our clk clock using a 3-bits shift register
reg [2:0] sck_r;
always @(posedge clk)
	sck_r <= {sck_r[1:0], sck};
wire sck_risingedge = (sck_r[2:1] == 2'b01);
wire sck_fallingedge = (sck_r[2:1] == 2'b10);

// same thing for sen
reg [2:0] sen_r;
always @(posedge clk)
	sen_r <= {sen_r[1:0], sen};
wire sen_active = ~sen_r[1];  // sen is active low
wire sen_risingedge = (sen_r[2:1]==2'b01);
wire sen_fallingedge = (sen_r[2:1]==2'b10);

// and for sdi
reg [1:0] sdi_r;
always @(posedge clk)
	sdi_r <= {sdi_r[0], sdi};
wire sdi_data = sdi_r[1];


// receiving side
reg [79:0] spireg = 0;

always @(posedge clk) begin
	if (~sen_active)
		spireg[7:0] <= 0;
	else if (sck_risingedge) begin
		spireg <= { spireg[78:0], sdi };
	end
end

// sending side
reg [15:0] sporeg = 0;

always @(posedge clk)
	if (sen_active) begin
		if(sen_fallingedge) begin
			sporeg <= status;
		end else if (sck_fallingedge) begin
			sporeg <= { sporeg[14:0], 1'b0 };
			sdo <= sporeg[15];
		end
	end

wire cmd_start = (sen_risingedge && spireg[7:0] == 8'h81);
wire cmd_queue = (sen_risingedge && spireg[7:0] == 8'h82);
wire cmd_steps_per_rev = (sen_risingedge && spireg[7:0] == 8'h83);
wire cmd_home_tolerance = (sen_risingedge && spireg[7:0] == 8'h84);
wire cmd_home_request = (sen_risingedge && spireg[7:0] == 8'h85);

assign wr_en = cmd_queue;
reg start = 0;

always @(posedge clk) begin
	start <= cmd_start;
	if (cmd_steps_per_rev)
		steps_per_rev <= spireg[32:8];
	if (cmd_home_tolerance)
		home_tolerance <= spireg[29:8];
	home_request <= cmd_home_request;
end

wire [6:0] elemcnt;
fifo u_fifo(
	.clk(clk),

	// write side
	.din(spireg[79:8]),
	.wr_en(wr_en),
	.full(),

	// read side
	.dout(rd_data),
	.rd_en(rd_en),
	.empty(rd_empty),

	// status
	.elemcnt(elemcnt)
);

wire do_step;
wire next_dir;
wire idle;
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
	.running(running),
	.idle(idle)
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
wire missed_round;
wire out_of_sync;

home u_home(
	.clk(clk),

	.step(do_step),
	.dir(next_dir),

	.home(home),
	.rev(rev),

	.steps_per_rev(steps_per_rev),
	.home_request(home_request),
	.home_tolerance(home_tolerance),

	.locked(locked),
	.missed_round(missed_round),
	.out_of_sync(out_of_sync)
);

//
// status output via spi
//
assign status[7:0] = elemcnt;
assign status[8] = running;
assign status[9] = underflow;
assign status[10] = idle;
assign status[11] = locked;
assign status[12] = missed_round;
assign status[13] = out_of_sync;
assign status[14] = 1;
assign status[15] = 1;

//
// route debug output
//
assign debug1 = locked; 	// yellow
assign debug2 = home;		// orange
assign debug3 = missed_round;	// red
assign debug4 = out_of_sync;	// brown

endmodule
