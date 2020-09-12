`include "defines.v"

module regfile(

	input wire clk,
	input wire rst,
	
	// 寫端口
	input wire we,
	input wire[`RegAddrBus] waddr, // 寫入的目的位址
	input wire[`RegBus] wdata, // 寫入資料
	
	// 讀端口 1
	input wire re1,
	input wire[`RegAddrBus] raddr1, // 讀出的位址 1
	output reg[`RegBus] rdata1, // 讀出的資料 1
	
	// 讀端口 2
	input wire re2,
	input wire[`RegAddrBus] raddr2, // 讀出的位址 2
	output reg[`RegBus] rdata2 // 讀書的資料 2
	
);

reg[`RegBus]  regs[0:`RegNum-1]; // Regfile: 32 個 32bits 暫存器檔

// 同步寫操作
always @ (posedge clk) begin
	if (rst == `RstDisable) begin
		if((we == `WriteEnable) && (waddr != `RegNumLog2'h0)) begin // $0 值恆為 0
			regs[waddr] <= wdata;
		end
	end
end

// 非同步讀端口 1操作
always @ (*) begin
	if(rst == `RstEnable) begin
		rdata1 <= `ZeroWord;
	end else if(raddr1 == `RegNumLog2'h0) begin
		rdata1 <= `ZeroWord;
	end else if((raddr1 == waddr) && (we == `WriteEnable) && (re1 == `ReadEnable)) begin // 支持同步讀寫 (解決相隔兩條指令的數據危障)
		rdata1 <= wdata;
	end else if(re1 == `ReadEnable) begin
		rdata1 <= regs[raddr1];
	end else begin
		rdata1 <= `ZeroWord;
	end
end

// 非同步讀端口 2操作
always @ (*) begin
	if(rst == `RstEnable) begin
		rdata2 <= `ZeroWord;
	end else if(raddr2 == `RegNumLog2'h0) begin
		rdata2 <= `ZeroWord;
	end else if((raddr2 == waddr) && (we == `WriteEnable) && (re2 == `ReadEnable)) begin
		rdata2 <= wdata;
	end else if(re2 == `ReadEnable) begin
		rdata2 <= regs[raddr2];
	end else begin
		rdata2 <= `ZeroWord;
	end
end

endmodule