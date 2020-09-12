
`timescale 1ns/10ps
`define RstEn 1'b1
`define RstDisEn 1'b0
`define Batch 9
`define MemAddrBus 0:8
`define InputBus 7:0
`define OutputBus 9:0
`define ZeroInput 8'b00000000
`define AllOneInput 8'b11111111

module CS(Y, X, reset, clk);

input clk,reset; 
input [`InputBus] X;
output reg [`OutputBus] Y;

reg [11:0] sum;
reg [`InputBus] mem[`MemAddrBus];
wire[`InputBus] res1_1,
				res1_2,
				res1_3,
				res1_4,
				res2_1,
				res2_2,
				res3_1;
				
wire [`InputBus] avg;
wire [`InputBus] appr;

assign avg = sum / `Batch;

assign res1_1 = (mem[0] > mem[1])? (mem[0] <= avg)? mem[0]:(mem[1] <= avg)? mem[1]:`ZeroInput : (mem[1] <= avg)? mem[1]:(mem[0] <= avg)? mem[0]:`ZeroInput;
assign res1_2 = (mem[2] > mem[3])? (mem[2] <= avg)? mem[2]:(mem[3] <= avg)? mem[3]:`ZeroInput : (mem[3] <= avg)? mem[3]:(mem[2] <= avg)? mem[2]:`ZeroInput;
assign res1_3 = (mem[4] > mem[5])? (mem[4] <= avg)? mem[4]:(mem[5] <= avg)? mem[5]:`ZeroInput : (mem[5] <= avg)? mem[5]:(mem[4] <= avg)? mem[4]:`ZeroInput;
assign res1_4 = (mem[6] > mem[7])? (mem[6] <= avg)? mem[6]:(mem[7] <= avg)? mem[7]:`ZeroInput : (mem[7] <= avg)? mem[7]:(mem[6] <= avg)? mem[6]:`ZeroInput;
assign res2_1 = (res1_1 >= res1_2)? res1_1 : res1_2;
assign res2_2 = (res1_3 >= res1_4)? res1_3 : res1_4;
assign res3_1 = (res2_1 >= res2_2)? res2_1 : res2_2;
assign appr = (res3_1 >= mem[8])? res3_1:(mem[8]<=avg)? mem[8]:res3_1;

wire [11:0] temp1;
assign temp1 = {appr,3'b0} + appr + sum;

always @(negedge clk) begin
	Y <= {3'b0,temp1[11:3]};
end

always @(posedge clk) begin

	if (reset == `RstEn) begin
	
		Y <= 10'bxxxxxxxxxx;
		sum <= 12'd0;
		
		mem[0] <= {`ZeroInput};
		mem[1] <= {`ZeroInput};
		mem[2] <= {`ZeroInput};
		mem[3] <= {`ZeroInput};
		mem[4] <= {`ZeroInput};
		mem[5] <= {`ZeroInput};
		mem[6] <= {`ZeroInput};
		mem[7] <= {`ZeroInput};
		mem[8] <= {`ZeroInput};
	end
	else begin
	
		sum = sum - mem[0];
		sum = sum + X;
		
		mem[0] = mem[1];
		mem[1] = mem[2];
		mem[2] = mem[3];
		mem[3] = mem[4];
		mem[4] = mem[5];
		mem[5] = mem[6];
		mem[6] = mem[7];
		mem[7] = mem[8];
		mem[8] = X;
			
	end
end


endmodule


