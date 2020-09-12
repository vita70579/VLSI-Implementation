`include "defines.v"

module regfile(

	input wire clk,
	input wire rst,
	
	// �g�ݤf
	input wire we,
	input wire[`RegAddrBus] waddr, // �g�J���ت���}
	input wire[`RegBus] wdata, // �g�J���
	
	// Ū�ݤf 1
	input wire re1,
	input wire[`RegAddrBus] raddr1, // Ū�X����} 1
	output reg[`RegBus] rdata1, // Ū�X����� 1
	
	// Ū�ݤf 2
	input wire re2,
	input wire[`RegAddrBus] raddr2, // Ū�X����} 2
	output reg[`RegBus] rdata2 // Ū�Ѫ���� 2
	
);

reg[`RegBus]  regs[0:`RegNum-1]; // Regfile: 32 �� 32bits �Ȧs����

// �P�B�g�ާ@
always @ (posedge clk) begin
	if (rst == `RstDisable) begin
		if((we == `WriteEnable) && (waddr != `RegNumLog2'h0)) begin // $0 �ȫ� 0
			regs[waddr] <= wdata;
		end
	end
end

// �D�P�BŪ�ݤf 1�ާ@
always @ (*) begin
	if(rst == `RstEnable) begin
		rdata1 <= `ZeroWord;
	end else if(raddr1 == `RegNumLog2'h0) begin
		rdata1 <= `ZeroWord;
	end else if((raddr1 == waddr) && (we == `WriteEnable) && (re1 == `ReadEnable)) begin // ����P�BŪ�g (�ѨM�۹j������O���ƾڦM��)
		rdata1 <= wdata;
	end else if(re1 == `ReadEnable) begin
		rdata1 <= regs[raddr1];
	end else begin
		rdata1 <= `ZeroWord;
	end
end

// �D�P�BŪ�ݤf 2�ާ@
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