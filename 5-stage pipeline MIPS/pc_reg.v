`include "defines.v"

module pc_reg(

	input wire clk,
	input wire rst, // 重置
	input wire[5:0] stall, // CTRL 管線暫停
	
	// 轉移指令
	input wire branch_flag_i,	// 是否發生轉移
	input wire [`RegBus] branch_target_address_i,	// 轉移目的位址
	
	output reg[`InstAddrBus] pc,
	output reg ce
	
);

/// PC 初始值為 32'0 即第一條指令，往後每過一個週期 +4
always @ (posedge clk) begin
	if (ce == `ChipDisable) begin
		pc <= 32'h00000000;
	end
	else if (stall[0] == `NoStop) begin
	
		if (branch_flag_i == `Branch) begin
			pc <= branch_target_address_i;
		end
		else begin
			pc <= pc + 4'h4;
		end
	end
	// 沒有完善 else 等價於合成一個 Latch : pc <= pc
end

always @ (posedge clk) begin
	if (rst == `RstEnable) begin
		ce <= `ChipDisable;
	end
	else begin
		ce <= `ChipEnable;
	end
end

endmodule