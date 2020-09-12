`include "defines.v"

module if_id(

	input wire clk,
	input wire rst,
	input wire[5:0] stall,
	

	input wire[`InstAddrBus] if_pc, // 指令位址
	input wire[`InstBus] if_inst, // 指令
	output reg[`InstAddrBus] id_pc, // 輸出指令位址到解碼階段
	output reg[`InstBus] id_inst  // 輸出指令到解碼階段
	
);

always @ (posedge clk) begin
	if (rst == `RstEnable) begin
		id_pc <= `ZeroWord;
		id_inst <= `ZeroWord;
	end
	else if (stall[1] == `Stop && stall[2] == `NoStop) begin
		id_pc <= `ZeroWord;
		id_inst <= `ZeroWord;
	end
	else if (stall[1] == `NoStop) begin
		id_pc <= if_pc;
		id_inst <= if_inst;
	end
end

endmodule