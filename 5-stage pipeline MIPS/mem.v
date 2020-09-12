`include "defines.v"

module mem(
	input wire rst,
	
	// 來自執行階段的信息
	input wire wreg_i,
	input wire[`RegAddrBus] wd_i,
	input wire[`RegBus] wdata_i,
	
	// 來自執行階段的信息: HI LO
	input wire whilo_i,
	input wire[`RegBus] hi_i,
	input wire[`RegBus] lo_i,
	
	// 送到回寫階段的信息
	output reg wreg_o,
	output reg[`RegAddrBus] wd_o,
	output reg[`RegBus] wdata_o,
	
	// 送到回寫階段的信息: HI LO
	output reg whilo_o,
	output reg[`RegBus] hi_o,
	output reg[`RegBus] lo_o
	
	
);

	
always @ (*) begin
	if(rst == `RstEnable) begin
		// Regfile
		wd_o <= `NOPRegAddr;
		wreg_o <= `WriteDisable;
		wdata_o <= `ZeroWord;
		
		// HILO
		hi_o <= `ZeroWord;
		lo_o <= `ZeroWord;
		whilo_o <= `WriteDisable;
	end
	else begin
		// Regfile
		wd_o <= wd_i;
		wreg_o <= wreg_i;
		wdata_o <= wdata_i;
		
		// HILO
		hi_o <= hi_i;
		lo_o <= lo_i;
		whilo_o <= whilo_i;
		
	end
end
endmodule