`include "defines.v"

module ex(

	input wire rst,
	output reg stallreq,
	
	// 送到執行階段的信息
	input wire[`AluOpBus] aluop_i,
	input wire[`AluSelBus] alusel_i,
	input wire[`RegBus] reg1_i,
	input wire[`RegBus] reg2_i,
	input wire[`RegAddrBus] wd_i,
	input wire wreg_i,

	output reg wreg_o,
	output reg[`RegAddrBus] wd_o,
	output reg[`RegBus]	wdata_o,
	
	/*
	HI LO 模組
	   取得 HI,LO 值
	   輸出 HI,LO 值
	*/
	input wire[`RegBus] hi_i,
	input wire[`RegBus] lo_i,
	output reg whilo_o,
	output reg[`RegBus] hi_o,
	output reg[`RegBus] lo_o,
	
	/// 解決 mfhi,mflo 數據危障問題 (因不涉及 Regfile 所以前饋至 EXE 階段)
	
	input wire mem_whilo_i, // MEM 階段是否要寫入 HI LO
	input wire[`RegBus] mem_hi_i, // 欲寫入 HI 的數據
	input wire[`RegBus] mem_lo_i, // 欲寫入 LO 的數據
	
	input wire wb_whilo_i, // WB 階段是否要寫入 HI LO
	input wire[`RegBus] wb_hi_i, // 欲寫入 HI 的數據
	input wire[`RegBus] wb_lo_i, // 欲寫入 LO 的數據
	
	/*
	用於累進運算的端口
	(a) 要將第一個執行週期得到的乘法結果存放於 ex/mem 階段的暫存器
	(b) 在第二個階段時取回進行壘加
	(c) 要計數執行週期
	*/
	
	output reg[`DoubleRegBus] hilo_temp_o,
	output reg[1:0] cnt_o,
	input wire[`DoubleRegBus] hilo_temp_i,
	input wire[1:0] cnt_i,
	
	// 除法指令端口
	input wire[`DoubleRegBus] div_result_i,
	input wire div_ready_i,
	
	output reg[`RegBus] div_opdata1_o,
	output reg[`RegBus] div_opdata2_o,
	output reg div_start_o,
	output reg signed_div_o,
	
	// 轉移指令訊息
	input wire[`RegBus] link_address_i,
	input wire is_in_delayslot_i
);

reg[`RegBus] logicout; // 保存邏輯運算結果
reg[`RegBus] shiftres; // 保存位移運算結果
reg[`RegBus] moveres; // 保存移動運算結果
reg[`RegBus] arithmeticres; // 保存算數運算結果

reg[`RegBus] HI; // 保存 HI 暫存器最新值
reg[`RegBus] LO; // 保存 LO 暫存器最新值

// 算術運算所需
wire ov_sum; // 保存溢位情形
wire reg1_eq_reg2;
wire reg1_lt_reg2;
wire[`RegBus] reg2_i_mux; // 保存輸入的第二個操作數的補數
wire[`RegBus] reg1_i_not; // 保存輸入的第一個操作數的反
wire[`RegBus] result_sum; // 保存加法結果
wire[`RegBus] opdata1_mult; // 乘法中的被乘數
wire[`RegBus] opdata2_mult; // 乘法中的乘數
wire[`DoubleRegBus] hilo_temp; // 臨時乘法結果 (64 bits)	* 此處的臨時乘法結果用於判斷是否做有號數乘法修正 
reg[`DoubleRegBus] hilo_temp1; // 用於保存乘累加/減的最終輸出
reg[`DoubleRegBus] mulres; // 一般乘法指令的乘法結果 (64 bits) / 乘累加減的第一階段乘法結果

reg stallreq_for_madd_msub; // 用於告知 stallreq 來自何種指令
reg stallreq_for_div;



// 對 Regfile 操作信息 (是否寫回暫存器/寫回的暫存器地址/寫回的資料)
always @ (*) begin
	wd_o <= wd_i; // 目標暫存器位址
	wreg_o <= wreg_i; // 是否寫入目的暫存器
	
	// 算數運算結果溢位時不寫入暫存器!
	if(((aluop_i == `EXE_ADD_OP) || (aluop_i == `EXE_ADDI_OP) || (aluop_i == `EXE_SUB_OP)) && (ov_sum == 1'b1)) begin
	 	wreg_o <= `WriteDisable;
	end
	else begin
		wreg_o <= wreg_i;
	end
	
	case ( alusel_i ) // 輸出
	 	`EXE_RES_LOGIC: begin
	 		wdata_o <= logicout;
	 	end
		`EXE_RES_SHIFT: begin
			wdata_o <= shiftres;
		end
		`EXE_RES_MOVE: begin
			wdata_o <= moveres;
		end
		`EXE_RES_ARITHMETIC: begin
	 		wdata_o <= arithmeticres;
	 	end
	 	`EXE_RES_MUL: begin
	 		wdata_o <= mulres[31:0];
		end
		`EXE_RES_JUMP_BRANCH:	begin
	 		wdata_o <= link_address_i;
	 	end
	 	default: begin
	 		wdata_o <= `ZeroWord;
	 	end
	endcase
end

// 對 HILO 操作信息
always @ (*) begin
	if (rst == `RstEnable) begin
		whilo_o <= `WriteDisable;
		hi_o <= `ZeroWord;
		lo_o <= `ZeroWord;
	end
	else begin
		case (aluop_i)
		// 除法運算
			`EXE_DIV_OP,`EXE_DIVU_OP: begin
				whilo_o <= `WriteEnable;
				hi_o <= div_result_i[63:32];
				lo_o <= div_result_i[31:0];
			end
		// MTHI MTLO 的移動運算
			`EXE_MTHI_OP: begin
				whilo_o <= `WriteEnable;
				hi_o <= reg1_i;
				lo_o <= LO;
			end
			`EXE_MTLO_OP: begin
				whilo_o <= `WriteEnable;
				hi_o <= HI;
				lo_o <= reg1_i;
			end
		
		// MULT MUL 的乘法運算
			`EXE_MULT_OP,`EXE_MULTU_OP: begin
				whilo_o <= `WriteEnable;
				hi_o <= mulres[63:32];
				lo_o <= mulres[31:0];
			end
		// MADD MADDU MSUB MSUBU 的乘法運算
			`EXE_MADD_OP,`EXE_MADDU_OP: begin
				whilo_o <= `WriteEnable;
				hi_o <= hilo_temp1[63:32];
				lo_o <= hilo_temp1[31:0];
			end
			`EXE_MSUB_OP,`EXE_MSUBU_OP: begin
				whilo_o <= `WriteEnable;
				hi_o <= hilo_temp1[63:32];
				lo_o <= hilo_temp1[31:0];
			end
			default: begin
			end
		endcase
	end
end

// 1. 解決移動指令的數據危障問題
// 2. 保存 HILO 最新值 到 HI LO 暫存器
always @ (*) begin
	if (rst == `RstEnable) begin
		{HI,LO} <= {`ZeroWord,`ZeroWord};
	end
	else if (mem_whilo_i == `WriteEnable) begin
		{HI,LO} <= {mem_hi_i,mem_lo_i};
	end
	else if (wb_whilo_i == `WriteEnable) begin
		{HI,LO} <= {wb_hi_i,wb_lo_i};
	end
	else begin
		{HI,LO} <= {hi_i,lo_i};
	end
end

// 管線暫停來源
always @ (*) begin
	stallreq = stallreq_for_madd_msub || stallreq_for_div;
end

/// 除法運算
always @ (*) begin
	if (rst == `RstEnable) begin
		stallreq_for_div <= `NoStop;
		div_opdata1_o <= `ZeroWord;
		div_opdata2_o <= `ZeroWord;
		div_start_o <= `DivStop;
		signed_div_o <= 1'b0;
	end
	else begin
	// 初始化
		stallreq_for_div <= `NoStop;
		div_opdata1_o <= `ZeroWord;
		div_opdata2_o <= `ZeroWord;
		div_start_o <= `DivStop;
		signed_div_o <= 1'b0;
		
		case(aluop_i)
			`EXE_DIV_OP: begin
				if (div_ready_i == `DivResultNotReady) begin
				// 在除法結果得到前持續管線暫停
					stallreq_for_div <= `Stop;
					
					// 雖然在每個周期都會輸入相同的運算來源，但除法模組中只對第一次輸入的來源運算 32 個週期後輸出，並不會重新計算!
					div_opdata1_o <= reg1_i;
					div_opdata2_o <= reg2_i;
					div_start_o <= `DivStart;
					signed_div_o <= 1'b1;
				end
				else if (div_ready_i == `DivResultReady) begin
					stallreq_for_div <= `NoStop;
				
					div_opdata1_o <= reg1_i;
					div_opdata2_o <= reg2_i;
					div_start_o <= `DivStop;	// 停止除法計算
					signed_div_o <= 1'b0;
				end
				else begin
					stallreq_for_div <= `NoStop;
					div_opdata1_o <= `ZeroWord;
					div_opdata2_o <= `ZeroWord;
					div_start_o <= `DivStop;
					signed_div_o <= 1'b0;
				end
			end
			`EXE_DIVU_OP: begin
				if (div_ready_i == `DivResultNotReady) begin
				// 在除法結果得到前持續管線暫停
					stallreq_for_div <= `Stop;
					
					// 雖然在每個周期都會輸入相同的運算來源，但除法模組中只對第一次輸入的來源運算 32 個週期後輸出，並不會重新計算!
					div_opdata1_o <= reg1_i;
					div_opdata2_o <= reg2_i;
					div_start_o <= `DivStart;
					signed_div_o <= 1'b0;
				end
				else if (div_ready_i == `DivResultReady) begin
					stallreq_for_div <= `NoStop;
				
					div_opdata1_o <= reg1_i;
					div_opdata2_o <= reg2_i;
					div_start_o <= `DivStop;	// 停止除法計算
					signed_div_o <= 1'b0;
				end
				else begin
					stallreq_for_div <= `NoStop;
					div_opdata1_o <= `ZeroWord;
					div_opdata2_o <= `ZeroWord;
					div_start_o <= `DivStop;
					signed_div_o <= 1'b0;
				end
			end
			default: begin
			end
		endcase
	end
end

/*
 算術運算 (一) - 加/減/比較/計數
	1. 若為 減法 或 有號數比較 運算 => 第二個運算元必為補數 (reg2_i_mux = ~reg2_i+1)，否則不改變! (reg2_i_mux = reg2_i)
		將 reg1_i + reg2_i_mux  會有下列三種情況
		(a) 加法 (reg2_i_mux = reg2_i)	(b) 加補數 (減法) (reg2_i_mux = ~reg2_i+1)	(c) 加補數 (減法) (用於判斷) (reg2_i_mux = ~reg2_i+1)
	2. 溢位判斷 (僅發生在 ADD ADDI SUB) Hint: 減法沒有立即指令
		(a) 正 + 正 = 負	(b) 負 + 負 = 正
	3. 比較
		(a) 無號數比較
			(a.1) 直接比較兩運算元大小 (運算元 1 < 運算元 2)
		(b) 有號數比較 (運算元 1 < 運算元 2 的三種情況)
			(b.1) 運算元 1 為負 2 為正
			(b.2) 運算元 1 為正 2 為正，且 result_sum < 0
			(b.3) 運算元 1 為負 2 為負，且 result_sum < 0
	4. 計數 0 or 1
		(a) 計 0
			a = 000000001010101010...
			a[31]? 0:a[30]? 1:...
		(b) 計 1
			b = 111111110101010101 => c = ~b = 000000001010101010...
			c[31]? 0:c[30]? 1:...
*/

assign reg2_i_mux = ((aluop_i == `EXE_SUB_OP) || (aluop_i == `EXE_SUBU_OP) || (aluop_i == `EXE_SLT_OP)) ? (~reg2_i) + 1 : reg2_i;	// 1.
assign result_sum = reg1_i + reg2_i_mux;
assign ov_sum = ((!reg1_i[31] && !reg2_i_mux[31]) && result_sum[31]) || ((reg1_i[31] && reg2_i_mux[31]) && (!result_sum[31]));	//2.
assign reg1_lt_reg2 = ((aluop_i == `EXE_SLT_OP)) ?
						((reg1_i[31] && !reg2_i[31]) ||
						(!reg1_i[31] && !reg2_i[31] && result_sum[31]) ||
						(reg1_i[31] && reg2_i[31] && result_sum[31]))
						:
						(reg1_i < reg2_i);	// 3.
assign reg1_i_not = ~reg1_i;	// 4.
						
always @ (*) begin
	if (rst == `RstEnable) begin
		arithmeticres <= `ZeroWord;
	end
	else begin
		case (aluop_i)
			`EXE_SLT_OP,`EXE_SLTU_OP: begin
				arithmeticres <= reg1_lt_reg2;
			end
			`EXE_ADD_OP,`EXE_ADDU_OP,`EXE_ADDI_OP,`EXE_ADDIU_OP: begin
				arithmeticres <= result_sum;
			end
			`EXE_SUB_OP,`EXE_SUBU_OP: begin
				arithmeticres <= result_sum;
			end
			`EXE_CLZ_OP: begin
				arithmeticres <= reg1_i[31] ? 0 : reg1_i[30] ? 1 : reg1_i[29] ? 2 :
								 reg1_i[28] ? 3 : reg1_i[27] ? 4 : reg1_i[26] ? 5 :
								 reg1_i[25] ? 6 : reg1_i[24] ? 7 : reg1_i[23] ? 8 : 
								 reg1_i[22] ? 9 : reg1_i[21] ? 10 : reg1_i[20] ? 11 :
								 reg1_i[19] ? 12 : reg1_i[18] ? 13 : reg1_i[17] ? 14 : 
								 reg1_i[16] ? 15 : reg1_i[15] ? 16 : reg1_i[14] ? 17 : 
								 reg1_i[13] ? 18 : reg1_i[12] ? 19 : reg1_i[11] ? 20 :
								 reg1_i[10] ? 21 : reg1_i[9] ? 22 : reg1_i[8] ? 23 : 
								 reg1_i[7] ? 24 : reg1_i[6] ? 25 : reg1_i[5] ? 26 : 
								 reg1_i[4] ? 27 : reg1_i[3] ? 28 : reg1_i[2] ? 29 : 
								 reg1_i[1] ? 30 : reg1_i[0] ? 31 : 32 ;
			end
			`EXE_CLO_OP: begin
				arithmeticres <= (reg1_i_not[31] ? 0 : reg1_i_not[30] ? 1 : reg1_i_not[29] ? 2 :
								 reg1_i_not[28] ? 3 : reg1_i_not[27] ? 4 : reg1_i_not[26] ? 5 :
								 reg1_i_not[25] ? 6 : reg1_i_not[24] ? 7 : reg1_i_not[23] ? 8 : 
								 reg1_i_not[22] ? 9 : reg1_i_not[21] ? 10 : reg1_i_not[20] ? 11 :
								 reg1_i_not[19] ? 12 : reg1_i_not[18] ? 13 : reg1_i_not[17] ? 14 : 
								 reg1_i_not[16] ? 15 : reg1_i_not[15] ? 16 : reg1_i_not[14] ? 17 : 
								 reg1_i_not[13] ? 18 : reg1_i_not[12] ? 19 : reg1_i_not[11] ? 20 :
								 reg1_i_not[10] ? 21 : reg1_i_not[9] ? 22 : reg1_i_not[8] ? 23 : 
								 reg1_i_not[7] ? 24 : reg1_i_not[6] ? 25 : reg1_i_not[5] ? 26 : 
								 reg1_i_not[4] ? 27 : reg1_i_not[3] ? 28 : reg1_i_not[2] ? 29 : 
								 reg1_i_not[1] ? 30 : reg1_i_not[0] ? 31 : 32) ;
			end
			default: begin
				arithmeticres <= `ZeroWord;
			end
		endcase
	end
end

/*
 算數運算 (二) -  乘法/乘累加 & 乘累減 運算
	1. 有號數乘法:
		若乘數或被乘數為負，將其作二補數。若異號相乘則乘積再取二補數!		*Booth: Booth 乘法結果即為有號數!
*/
assign opdata1_mult = ((aluop_i == `EXE_MUL_OP) || (aluop_i == `EXE_MULT_OP) || (aluop_i == `EXE_MADD_OP) || (aluop_i == `EXE_MSUB_OP)) && (reg1_i[31] == 1'b1) ? (~reg1_i + 1) : reg1_i;
assign opdata2_mult = ((aluop_i == `EXE_MUL_OP) || (aluop_i == `EXE_MULT_OP) || (aluop_i == `EXE_MADD_OP) || (aluop_i == `EXE_MSUB_OP)) && (reg2_i[31] == 1'b1) ? (~reg2_i + 1) : reg2_i;
assign hilo_temp = opdata1_mult * opdata2_mult;

// 臨時乘法結果的修正 (若異號相乘則成績再取二補數)
always @ (*) begin
	if (rst == `RstEnable) begin
		mulres <= {`ZeroWord,`ZeroWord};
	end
	else if ((aluop_i == `EXE_MUL_OP) || (aluop_i == `EXE_MULT_OP) || (aluop_i == `EXE_MADD_OP) || (aluop_i == `EXE_MSUB_OP)) begin	// 有號數乘法
		if (reg1_i[31] ^ reg2_i[31] == 1'b1) begin // 修正
			mulres <= (~hilo_temp + 1);
		end
		else begin
			mulres <= hilo_temp;
		end
	end
	else begin // 無號數乘法
		mulres <= hilo_temp;
	end
end

// 乘累加 & 乘累減 運算
always @ (*) begin
	if (rst == `RstEnable) begin
		hilo_temp_o <= {`ZeroWord,`ZeroWord};
		cnt_o <= 2'b00;
		stallreq_for_madd_msub <= `NoStop;
	end
	else begin
		case (aluop_i)
			`EXE_MADD_OP,`EXE_MADDU_OP: begin
				if (cnt_i == 2'b00) begin
					hilo_temp_o <= mulres;	// 將第一階段結果輸出到 ex/mem 階段的暫存器
					cnt_o <= 2'b01;	// 記錄當下處於第一階段運算
					hilo_temp1 <= {`ZeroWord,`ZeroWord};	// 最終輸出暫存器在第一階段運算時還是0
					stallreq_for_madd_msub <= `Stop;	// 管線暫停請求
				end
				else if (cnt_i == 2'b01) begin
					hilo_temp_o <= {`ZeroWord,`ZeroWord}; // 將輸出結果清零
					cnt_o <= 2'b10;
					hilo_temp1 <= hilo_temp_i + {HI,LO};
					stallreq_for_madd_msub <= `NoStop;
				end
			end
			`EXE_MSUB_OP,`EXE_MSUBU_OP: begin
				if (cnt_i == 2'b00) begin
					hilo_temp_o <= ~mulres + 1; // 乘累減 (第一階段結果取補數)
					cnt_o <= 2'b01;
					hilo_temp1 <= {`ZeroWord,`ZeroWord};
					stallreq_for_madd_msub <= `Stop;
				end
				else if (cnt_i == 2'b01) begin
					hilo_temp_o <= {`ZeroWord,`ZeroWord}; // 將輸出結果清零
					cnt_o <= 2'b10;
					hilo_temp1 <= hilo_temp_i + {HI,LO};
					stallreq_for_madd_msub <= `NoStop;
				end
			end
			default: begin
				hilo_temp_o <= {`ZeroWord,`ZeroWord};
				cnt_o <= 2'b00;
				stallreq_for_madd_msub <= `NoStop;
			end
		endcase
	end
end


// 移動運算
always @ (*) begin
	if (rst == `RstEnable) begin
		moveres <= `ZeroWord;
	end
	else begin
		case (aluop_i)
			`EXE_MFHI_OP: begin
				moveres <= HI;
			end
			`EXE_MFLO_OP: begin
				moveres <= LO;
			end
			`EXE_MOVZ_OP: begin
				moveres <= reg1_i;
			end
			`EXE_MOVN_OP: begin
				moveres <= reg1_i;
			end
			default: begin
			end
		endcase
	end
end


// 邏輯運算
always @ (*) begin
	if(rst == `RstEnable) begin
		logicout <= `ZeroWord;
	end else begin
		case (aluop_i) // 運算且保存
			`EXE_OR_OP:	begin
				logicout <= reg1_i | reg2_i;
			end
			`EXE_AND_OP: begin
				logicout <= reg1_i & reg2_i;
			end
			`EXE_NOR_OP: begin
				logicout <= ~(reg1_i | reg2_i);
			end
			`EXE_XOR_OP: begin
				logicout <= reg1_i ^ reg2_i;
			end
			default: begin
				logicout <= `ZeroWord;
			end
		endcase
	end
end

// 位移運算
always @ (*) begin
	if (rst == `RstEnable) begin
		shiftres <= `ZeroWord;
	end else begin
		case (aluop_i)
			`EXE_SLL_OP: begin
				shiftres <= reg2_i << reg1_i[4:0];
			end
			`EXE_SRL_OP: begin
				shiftres <= reg2_i >> reg1_i[4:0];
			end
			`EXE_SRA_OP: begin
				shiftres <= ({32{reg2_i[31]}} << (6'd32-{1'b0,reg1_i[4:0]})) | reg2_i >> reg1_i[4:0];
			end
			default: begin
				shiftres <= `ZeroWord;
			end
		endcase
	end
end



endmodule