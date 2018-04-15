`timescale 1ns / 1ps

module stepper(
	input	clk_50mhz,
	output	led_0,	// onboard
	output	led_1,	// bank 14, M12 (U7, pin 7)
	output	step,	// bank 14, N14 (U7, pin 9)
	output	dir,	// bank 14, P15 (U7, pin 11)
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

//
// generate clock
//
(* mark_debug = "true" *) wire clk;
wire clk_buf;
wire clk_feedback;
wire clk_feedback_bufd;
wire clk_locked;
wire ref_pll_locked;
wire clk_50_buf;

IBUF clk_in_buf(
	.I(clk_50mhz),
	.O(clk_50_buf)
);

PLLE2_BASE #(
	.BANDWIDTH("OPTIMIZED"),	// OPTIMIZED, HIGH, LOW
	.CLKFBOUT_PHASE(0.0),		// Phase offset in degrees of CLKFB, (-360-360)
	.CLKIN1_PERIOD(10.0),		// Input clock period in ns resolution
	// CLKOUT0_DIVIDE - CLKOUT5_DIVIDE: divide amount for each CLKOUT(1-128)
	.CLKFBOUT_MULT(20),	    	// Multiply value for all CLKOUT (2-64)
	.CLKOUT0_DIVIDE(50), 		// 20 MHz
	.CLKOUT1_DIVIDE(50),	     	// 20 MHz	(Unused)
	.CLKOUT2_DIVIDE(100),      	// 10 MHz	(Unused)
	.CLKOUT3_DIVIDE(100),		// 10 MHz	(Unused)
	.CLKOUT4_DIVIDE(100),		// 10 MHz	(Unused)
	.CLKOUT5_DIVIDE(100),		// 10 MHz
	// CLKOUT0_DUTY_CYCLE -- Duty cycle for each CLKOUT
	.CLKOUT0_DUTY_CYCLE(0.5),
	.CLKOUT1_DUTY_CYCLE(0.5),
	.CLKOUT2_DUTY_CYCLE(0.5),
	.CLKOUT3_DUTY_CYCLE(0.5),
	.CLKOUT4_DUTY_CYCLE(0.5),
	.CLKOUT5_DUTY_CYCLE(0.5),
	// CLKOUT0_PHASE -- phase offset for each CLKOUT
	.CLKOUT0_PHASE(0.0),
	.CLKOUT1_PHASE(0.0),
	.CLKOUT2_PHASE(0.0),
	.CLKOUT3_PHASE(0.0),
	.CLKOUT4_PHASE(0.0),
	.CLKOUT5_PHASE(0.0),
	.DIVCLK_DIVIDE(1),		// Master division value , (1-56)
	.REF_JITTER1(0.0),		// Ref. input jitter in UI (0.000-0.999)
	.STARTUP_WAIT("TRUE")		// Delay DONE until PLL Locks, ("TRUE"/"FALSE")
) genclock(
	// Clock outputs: 1-bit (each) output
	.CLKOUT0(clk_buf),
	.CLKOUT1(),
	.CLKOUT2(),
	.CLKOUT3(),
	.CLKOUT4(),
	.CLKOUT5(),
	.CLKFBOUT(clk_feedback),	// 1-bit output, feedback clock
	.LOCKED(ref_pll_locked),
	.CLKIN1(clk_50_buf),
	.PWRDWN(1'b0),
	.RST(1'b0),
	.CLKFBIN(clk_feedback_bufd)	// 1-bit input, feedback clock
);

BUFH feedback_buffer(
	.I(clk_feedback),
	.O(clk_feedback_bufd)
);
BUFH clk_out_buf(
	.I(clk_buf),
	.O(clk)
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
reg [23:0] pos_counter = 0;
reg home_request = 0;

//assign rev = pos_counter == 0;
assign rev = pos_counter[23:8] == 0;

// read side of fifo
(* mark_debug = "true" *) wire rd_en;
(* mark_debug = "true" *) wire [71:0] rd_data;
(* mark_debug = "true" *) reg running = 0;
(* mark_debug = "true" *) reg underflow = 0;

//
// serial interface with entry side FIFO
//
(* mark_debug = "true" *) reg [79:0] spireg = 0;
(* mark_debug = "true" *) wire wr_en;
(* mark_debug = "true" *) wire rd_empty;
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

(* mark_debug = "true" *) wire cmd_valid = (sen3 == 1) && (sen4 == 0);
reg req_running_reset = 0;
assign wr_en = cmd_valid && (spireg[7:0] == 8'h9a);
wire set_running = (cmd_valid && spireg[7:0] == 8'hb5);
wire set_rev_register = (cmd_valid && spireg[7:0] == 8'ha3);
wire set_home_request = (cmd_valid && spireg[7:0] == 8'h3b);
reg req_home_reset;
always @(posedge clk) begin
	if (set_running)
		running <= 1;
	else if (req_running_reset)
		running <= 0;
	else if (set_rev_register)
		steps_per_rev <= spireg[32:8];
	else if (set_home_request)
		home_request <= 1;
	else if (req_home_reset)
		home_request <= 0;
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

//
// velocity state machine
//
// TODO: start signal
reg [35:0] cmd_cnt = 0;
reg [35:0] position = 0;
reg [35:0] velocity = 0;
reg [35:0] acceleration = 0;

// step calculation
wire do_step;
wire [35:0] new_position;
wire [35:0] new_velocity;
reg step_int = 0;

assign step = step_int;
assign {do_step, new_position} = {1'b0, position} + {1'b0, velocity};
assign new_velocity = velocity + acceleration;
assign led_1 = underflow;
assign rd_en = (cmd_cnt == 0) && running;

always @(posedge clk) begin
	if (cmd_cnt == 0 && !rd_empty && running) begin
		cmd_cnt <= rd_data[35:0];
		acceleration <= rd_data[71:36];
		underflow <= 0;
		// keep position and velocity
	end else if (cmd_cnt == 0) begin
		cmd_cnt <= 0;
		position <= 0;
		velocity <= 0;
		acceleration <= 0;
		if (underflow == 0)
			req_running_reset <= 1;
		else
			req_running_reset <= 0;
		underflow <= 1;
	end else begin
		cmd_cnt <= cmd_cnt - 1;
		velocity <= new_velocity;
		position <= new_position;
		if (do_step ^ velocity[35]) begin
			step_int <= ~step_int;
			if (home && home_request)
				req_home_reset <= 1;
			else
				req_home_reset <= 0;
			if (home && home_request) begin
				pos_counter <= 0;
			end else if (velocity[35]) begin
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
end

assign dir = velocity[35];
//
// route debug output
//
assign debug1 = spireg[1];	// yellow
assign debug2 = spireg[0];	// orange
assign debug3 = cmd_valid;	// red
assign debug4 = running;	// brown

endmodule
