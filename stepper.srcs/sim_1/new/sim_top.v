`timescale 1ns / 1ps

module stepper_sim_top();

reg clk_50mhz = 0;
wire led_0;
wire led_1;
wire step;
wire dir;
reg sck = 1;
reg sdi = 0;
reg sen = 1;
reg home = 0;
wire sdo;

stepper u_stepper(
	.clk_50mhz(clk_50mhz),
	.led_0(led_0),
	.led_1(led_1),
	.step(step),
	.dir(dir),
	.sck(sck),
	.sdi(sdi),
	.sen(sen),
	.sdo(sdo),
	.home(home)
);

initial begin: B_clk
	integer i;
	for (i = 1; i < 100000; i = i + 1) begin
		clk_50mhz = 1;
		#10;
		clk_50mhz = 0;
		#10;
	end
end

task ramp;
input [79:0] cmd;
begin : ramptask
	integer i;
	sen = 0;
	#200;
	for (i = 0; i < 80; i = i + 1) begin
		sck = 0;
		sdi = cmd[79];
		cmd = { cmd[78:0], 1'b0 };
		#150;
		sck = 1;
		#154;
	end
	sen = 1;
	#300;
end
endtask

task cmd;
input [7:0] cmd;
begin : ramptask
	integer i;
	sen = 0;
	#200;
	for (i = 0; i < 8; i = i + 1) begin
		sck = 0;
		sdi = cmd[7];
		cmd = { cmd[6:0], 1'b0 };
		#150;
		sck = 1;
		#154;
	end
	sen = 1;
	#300;
end
endtask

// cmd_start h81
// cmd_queue h82
// cmd_steps_per_rev h83
// cmd_home_tolerance h84
// cmd_home_request h85

reg [7:0] cmd3;
initial begin: C_cmd
	integer i;
	integer h;
	#5000;	// let pll settle
	for (h = 0; h < 3; h = h + 1) begin
		cmd(8'h85);	// home request
		ramp(80'h000000000_000000007_83); // steps/rev
		//ramp(80'h005000000_000000049_82);
		//ramp(80'hffbffffff_000000100_82);
		ramp(80'h000100000_000000100_82);
		ramp(80'h000000000_000001000_82);
		ramp(80'hffff00000_000000080_82);
		ramp(80'h000000000_000000000_82);
		cmd(8'h81);
		#1000;
		home = 1;
		#100;
		home = 0;
		#500000;
	end
end

endmodule
