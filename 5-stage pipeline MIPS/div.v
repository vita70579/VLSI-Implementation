`include "defines.v"

module div(
    input wire rst,
    input wire clk,
    
    input wire signed_div_i,    // 有號無號除法
    input wire start_i, // 開始除法運算
    input wire annul_i, // 取消除法運算
    input wire[`RegBus] opdata1_i,
    input wire[`RegBus] opdata2_i,
    
    output reg[`DoubleRegBus] result_o,
    
    output reg ready_o  // 除法結果尚未得到
);

wire[32:0] div_temp;
reg[5:0] cnt;
reg[64:0] dividend;
reg[31:0] divisor;
reg[31:0] temp_op1;
reg[31:0] temp_op2;

reg[1:0] state;     // 4種狀態

// minuend - n 組合電路
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
						
						// 若為有號運算則對運算來源取補數
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
						
						// DivOn 初始化
						dividend <= {`ZeroWord,`ZeroWord};
						dividend[32:1] <= temp_op1;	// 此處先將被除數左移 1 bit,因為第一步運算就須將被除數最高位元作為被減數!
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
					else begin	// 試商法結束
					// 有號數修正
					// (a) 運算來源異號 => "商數" 取 2 補數
					// (b) 被除數餘數異號 => "餘數" 取 2 補數
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