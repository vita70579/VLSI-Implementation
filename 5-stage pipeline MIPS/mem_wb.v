`include "defines.v"

module mem_wb(

	input wire clk,
	input wire rst,
	input wire[5:0] stall,
	

	// �Ӧ۳X�s���q���H��
	input wire mem_wreg,
	input wire[`RegAddrBus] mem_wd,
	input wire[`RegBus] mem_wdata,
	
	// �Ӧ۳X�s���q���H��: HILO
	input wire mem_whilo,
	input wire[`RegBus] mem_hi,
	input wire[`RegBus] mem_lo,

	// �e��^�g���q���H��
	output reg wb_wreg,
	output reg[`RegAddrBus] wb_wd,
	output reg[`RegBus] wb_wdata,
	
	// �e��^�g���q���H��: HILO
	output reg wb_whilo,
	output reg[`RegBus] wb_hi,
	output reg[`RegBus] wb_lo
	
);


always @ (posedge clk) begin
	if(rst == `RstEnable) begin
		// Regfile
		wb_wreg <= `WriteDisable;
		wb_wd <= `NOPRegAddr;
		wb_wdata <= `ZeroWord;
		
		// HILO
		wb_whilo <= `WriteDisable;
		wb_hi <= `ZeroWord;
		wb_lo <= `ZeroWord;
	end
	else if (stall[4] == `Stop && stall[5] == `NoStop) begin
		// Regfile
		wb_wreg <= `WriteDisable;
		wb_wd <= `NOPRegAddr;
		wb_wdata <= `ZeroWord;
		
		// HILO
		wb_whilo <= `WriteDisable;
		wb_hi <= `ZeroWord;
		wb_lo <= `ZeroWord;
	end
	else if (stall[4] == `NoStop) begin
		// Regfile
		wb_wreg <= mem_wreg;
		wb_wd <= mem_wd;
		wb_wdata <= mem_wdata;
		
		// HILO
		wb_whilo <= mem_whilo;
		wb_hi <= mem_hi;
		wb_lo <= mem_lo;
		
	end    //if
end      //always
			

endmodule