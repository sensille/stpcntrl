`timescale 1ns / 1ps

module stepper_sim_top();

reg clk_50mhz = 0;
wire led_0;
wire led_1;
wire step;
wire dir;
reg sck = 0;
reg sdi = 0;
reg sen = 0;

stepper u_stepper(
	.clk_50mhz(clk_50mhz),
	.led_0(led_0),
	.led_1(led_1),
	.step(step),
	.dir(dir),
	.sck(sck),
	.sdi(sdi),
	.sen(sen)
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
	for (i = 0; i < 80; i = i + 1) begin
		sdi = cmd[79];
		cmd = { cmd[78:0], 1'b0 };
		#13;
		sck = 1;
		#15;
		sck = 0;
		#10;
	end
	sen = 1;
	#300;
	sen = 0;
	#300;
end
endtask

task cmd;
input [7:0] cmd;
begin : ramptask
	integer i;
	for (i = 0; i < 8; i = i + 1) begin
		sdi = cmd[7];
		cmd = { cmd[6:0], 1'b0 };
		#13;
		sck = 1;
		#15;
		sck = 0;
		#10;
	end
	sen = 1;
	#300;
	sen = 0;
	#300;
end
endtask

reg [7:0] cmd3;
initial begin: C_cmd
	integer i;
	integer h;
	#5000;	// let pll settle
	for (h = 0; h < 3; h = h + 1) begin
//		cmd(8'h3a);	// home request
		ramp(80'h000000000_000000080_a3); // steps/rev
		//ramp(80'h005000000_000000049_9a);
		//ramp(80'hffbffffff_000000100_9a);
		ramp(80'h00fffffff_000000080_9a);
		ramp(80'h000000078_000000080_9a);
		ramp(80'h000000000_000000100_9a);
		ramp(80'hfffffff88_000000100_9a);
		ramp(80'h000000000_000000100_9a);
		ramp(80'hfffffff88_000000100_9a);
		ramp(80'h000000000_000000100_9a);
		ramp(80'hfffffff88_000000100_9a);
		ramp(80'h000000000_000000100_9a);
		cmd(8'hb5);
		#240000;
	end
end

endmodule
