`include "defines.v"

module if_id(

	input wire clk,
	input wire rst,
	input wire[5:0] stall,
	

	input wire[`InstAddrBus] if_pc, // ���O��}
	input wire[`InstBus] if_inst, // ���O
	output reg[`InstAddrBus] id_pc, // ��X���O��}��ѽX���q
	output reg[`InstBus] id_inst  // ��X���O��ѽX���q
	
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