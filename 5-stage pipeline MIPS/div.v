`include "defines.v"

module div(
    input wire rst,
    input wire clk,
    
    input wire signed_div_i,    // �����L�����k
    input wire start_i, // �}�l���k�B��
    input wire annul_i, // �������k�B��
    input wire[`RegBus] opdata1_i,
    input wire[`RegBus] opdata2_i,
    
    output reg[`DoubleRegBus] result_o,
    
    output reg ready_o  // ���k���G�|���o��
);

wire[32:0] div_temp;
reg[5:0] cnt;
reg[64:0] dividend;
reg[31:0] divisor;
reg[31:0] temp_op1;
reg[31:0] temp_op2;

reg[1:0] state;     // 4�ت��A

// minuend - n �զX�q��
assign div_temp = {1'b0,dividend[63:32]} - {1'b0,divisor};	// div_temp[32] => sign bit

always @ (posedge clk ) begin

    if (rst == `RstEnable) begin
        state <= `DivFree;
        ready_o <= `DivResultNotReady;
        result_o <= {`ZeroWord,`ZeroWord};
    end else begin
        case (state)
            `DivFree: begin
                if (start_i == `DivStart  && annul_i == 1'b0) begin
					if (opdata2_i == `ZeroWord) begin
						state <= `DivByZero;
					end
					else begin
						state <= `DivOn;
						cnt <= 6'b000000;
						
						// �Y�������B��h��B��ӷ����ɼ�
						if (signed_div_i == 1'b1 && opdata1_i[31] == 1'b1) begin
							temp_op1 = ~opdata1_i + 1;
						end
						else begin
							temp_op1 = opdata1_i;
						end
						
						if (signed_div_i == 1'b1 && opdata2_i[31] == 1'b1) begin
							temp_op2 = ~opdata2_i + 1;
						end
						else begin
							temp_op2 = opdata2_i;
						end
						
						// DivOn ��l��
						dividend <= {`ZeroWord,`ZeroWord};
						dividend[32:1] <= temp_op1;	// ���B���N�Q���ƥ��� 1 bit,�]���Ĥ@�B�B��N���N�Q���Ƴ̰��줸�@���Q���!
						divisor <= temp_op2;
					end
				end
				else begin
					ready_o <= `DivResultNotReady;
					result_o <= {`ZeroWord,`ZeroWord};
				end
            end
            `DivByZero: begin
				dividend <= {`ZeroWord,`ZeroWord};
				state <= `DivEnd;
            end
            `DivOn: begin
				if (annul_i == 1'b0) begin
					if (cnt != 6'b100000) begin
						if (div_temp[32] == 1'b1) begin
							dividend <= {dividend[63:0],1'b0}; // minuend = (minuend , m[k-1])
						end
						else begin
							dividend <= {div_temp[31:0] , dividend[31:0] , 1'b1};
						end
						cnt <= cnt + 1;
					end
					else begin	// �հӪk����
					// �����ƭץ�
					// (a) �B��ӷ����� => "�Ӽ�" �� 2 �ɼ�
					// (b) �Q���ƾl�Ʋ��� => "�l��" �� 2 �ɼ�
						if ((signed_div_i == 1'b1) && (opdata1_i[31] ^ opdata2_i[31]) == 1'b1) begin
							dividend[31:0] <= ~ dividend[31:0] + 1;
						end
						if ((signed_div_i == 1'b1) && (opdata1_i[31] ^ dividend[64]) == 1'b1) begin
							dividend[64:33] <= ~ dividend[64:33] +1;
						end
						state <= `DivEnd;
						cnt <= 6'b000000;
					end
				end
				else begin
					state <= `DivFree;
				end
            end
            `DivEnd: begin
				result_o <= {dividend[64:33],dividend[31:0]};
				ready_o <= `DivResultReady;
				if (start_i == `DivStop) begin
					state <= `DivFree;
					ready_o <= `DivResultNotReady;
					result_o <= {`ZeroWord,`ZeroWord};
				end
            end
        endcase
    end

end

endmodule