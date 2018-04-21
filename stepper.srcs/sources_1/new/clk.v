`timescale 1ns / 1ps

module clk(
	input	clk_50mhz,
	output	clk
);

//
// generate clock
//
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

endmodule
