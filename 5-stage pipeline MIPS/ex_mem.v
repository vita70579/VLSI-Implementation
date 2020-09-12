`include "defines.v"

module ex_mem(

	input wire clk,
	input wire rst,
	input wire[5:0] stall,
	
	
	// 來自執行階段的信息
	input wire ex_wreg,
	input wire[`RegAddrBus] ex_wd,
	input wire[`RegBus] ex_wdata,
	
	// 來自執行階段的信息: HI LO
	input wire ex_whilo,
	input wire[`RegBus] ex_hi,
	input wire[`RegBus] ex_lo,
	
	// 送到訪存階段的信息
	output reg mem_wreg,
	output reg[`RegAddrBus] mem_wd,
	output reg[`RegBus] mem_wdata,
	
	// 來自訪存階段的信息: HI LO
	output reg mem_whilo,
	output reg[`RegBus] mem_hi,
	output reg[`RegBus] mem_lo,
	
	// 輸入臨時的乘法結果 (乘累加/減指令)
	input wire[`DoubleRegBus] hilo_i,
	input wire[1:0] cnt_i,
	
	output reg[`DoubleRegBus] hilo_o,
	output reg[1:0] cnt_o
	
);


always @ (posedge clk) begin
	if(rst == `RstEnable) begin
		mem_wd <= `NOPRegAddr;
		mem_wreg <= `WriteDisable;
		mem_wdata <= `ZeroWord;	
		
		mem_hi <= `ZeroWord;
		mem_lo <= `ZeroWord;
		mem_whilo <= `WriteDisable;
		
	end
	else if (stall[3] == `Stop && stall[4] == `NoStop) begin
		mem_wd <= `NOPRegAddr;
		mem_wreg <= `WriteDisable;
		mem_wdata <= `ZeroWord;	
		
		mem_hi <= `ZeroWord;
		mem_lo <= `ZeroWord;
		mem_whilo <= `WriteDisable;
		
		// 
		hilo_o <= hilo_i;
		cnt_o <= cnt_i;
	end
	else if (stall[3] == `NoStop) begin
		mem_wd <= ex_wd;
		mem_wreg <= ex_wreg;
		mem_wdata <= ex_wdata;

		// HI LO
		mem_hi <= ex_hi;
		mem_lo <= ex_lo;
		mem_whilo <= ex_whilo;
		
		//
		hilo_o <= {`ZeroWord,`ZeroWord};
		cnt_o <= 2'b00;
	end
	else begin
		hilo_o <= hilo_i; 
		cnt_o <= cnt_i; 
	end		//if
end		//always
endmodule