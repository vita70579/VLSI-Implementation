`include "defines.v"

module pc_reg(

	input wire clk,
	input wire rst, // ���m
	input wire[5:0] stall, // CTRL �޽u�Ȱ�
	
	// �ಾ���O
	input wire branch_flag_i,	// �O�_�o���ಾ
	input wire [`RegBus] branch_target_address_i,	// �ಾ�ت���}
	
	output reg[`InstAddrBus] pc,
	output reg ce
	
);

/// PC ��l�Ȭ� 32'0 �Y�Ĥ@�����O�A����C�L�@�Ӷg�� +4
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
	// �S������ else ������X���@�� Latch : pc <= pc
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