`include "defines.v"

module id(

	input wire rst,
	output wire stallreq, // 管線暫停信號	
	
	input wire[`InstAddrBus] pc_i, // 存放指令的位址
	input wire[`InstBus] inst_i, // 待解碼的指令

	input wire[`RegBus] reg1_data_i, // 從 Regfile 讀到的 暫存器1值 
	input wire[`RegBus] reg2_data_i, // 從 Regfile 讀到的 暫存器2值 

	//送到regfile的信息
	output reg reg1_read_o,
	output reg reg2_read_o,     
	output reg[`RegAddrBus] reg1_addr_o,
	output reg[`RegAddrBus] reg2_addr_o, 	      
	
	//送到執行階段的信息
	output reg[`AluOpBus] aluop_o, // 在 EXE 階段要執行的運算 (並非機器碼，而是 EXE 階段 CASE 的編號)
	output reg[`AluSelBus] alusel_o, // ALU 類型 (Logic Shift Load...) (並非機器碼，而是 EXE 階段 CASE 的編號)
	output reg[`RegBus] reg1_o, // 從 Regfile 讀到的 暫存器1值，即rs 暫存器值。
	output reg[`RegBus] reg2_o, // 從 Regfile 讀到的 暫存器1值，即rt 暫存器值。
	output reg[`RegAddrBus] wd_o, // 目標暫存器位址
	output reg wreg_o, // read enable
	
	/// 解決數據危障：前饋
	// 處於 EXE 階段的指令的運算結果
	input wire ex_wreg_i, // 執行階段結果是否寫回暫存器
	input wire[`RegBus] ex_wdata_i, // 執行階段要寫回暫存器的值
	input wire[`RegAddrBus] ex_wd_i, // 執行階段要寫回的目的暫存器位址
	
	// 處於 MEM 階段的指令的運算結果
	input wire mem_wreg_i, // MEM 階段結果是否寫回暫存器
	input wire[`RegBus] mem_wdata_i, // MEM 階段要寫回暫存器的值
	input wire[`RegAddrBus] mem_wd_i, // MEM 階段要寫回的目的暫存器位址
	
	// 轉移指令
	input wire is_in_delayslot_i,	// 當前處於譯碼階段的指令是否位於延遲槽
	
	output reg is_in_delayslot_o,	// 當前處於譯碼階段的指令是否位於延遲槽
	output reg next_inst_in_delayslot_o,	// 下一條進入譯碼階段指令是否位於延遲槽
	output reg branch_flag_o,	// 是否發生轉移
	output reg[`RegBus] branch_target_address_o,	// 轉移目標位址
	output reg[`RegBus] link_addr_o // 轉移指令要保存的返回位址
	
	
	
);

assign stallreq = `NoStop;

/// 指令種類可以依序按照 [31:26][10:6][5:0] 分類...
wire[5:0] op = inst_i[31:26]; // op code
wire[4:0] op2 = inst_i[10:6];
wire[5:0] op3 = inst_i[5:0]; // funct
wire[4:0] op4 = inst_i[20:16];

reg[`RegBus] imm; // 立即數
reg instvalid; // 指令是否有效

// 轉移指令
wire [`RegBus] pc_plus_8;	// 保存當前指令後第二條指令位址
wire [`RegBus] pc_plus_4;	// 保存當前指令後一條指令位址
wire [`RegBus] imm_sll2_signedext; // 所有分支指令的轉移目標地址為: 「(signed_extend){offset,00}」 + (pc+4)

assign pc_plus_4 = pc_i + 4 ;
assign pc_plus_8 = pc_i + 8 ;
assign imm_sll2_signedext = {{14{inst_i[15]}},inst_i[15:0],2'b00};	// 條件轉移指令的 offset 為指令後 16 bits.
 
always @ (*) begin	
	if (rst == `RstEnable) begin
		aluop_o <= `EXE_NOP_OP;
		alusel_o <= `EXE_RES_NOP;
		wd_o <= `NOPRegAddr;
		wreg_o <= `WriteDisable;
		instvalid <= `InstValid;
		reg1_read_o <= 1'b0;
		reg2_read_o <= 1'b0;
		reg1_addr_o <= `NOPRegAddr;
		reg2_addr_o <= `NOPRegAddr;
		imm <= 32'h0;
		
		// 轉移指令
		link_addr_o <= `ZeroWord;
		branch_target_address_o <= `ZeroWord;
		branch_flag_o <= `NotBranch;
		next_inst_in_delayslot_o <= `NotInDelaySlot;
	end else begin
		// Initialization
		aluop_o <= `EXE_NOP_OP;
		alusel_o <= `EXE_RES_NOP;
		
		wd_o <= inst_i[15:11];
		wreg_o <= `WriteDisable;
		
		instvalid <= `InstInvalid;	  
		
		reg1_read_o <= 1'b0;
		reg2_read_o <= 1'b0;
		reg1_addr_o <= inst_i[25:21]; // 從 Regfile 讀 rs 暫存器位址
		reg2_addr_o <= inst_i[20:16]; // 從 Regfile 讀 rt 暫存器位址
		
		// 轉移指令
		link_addr_o <= `ZeroWord;
		branch_target_address_o <= `ZeroWord;
		branch_flag_o <= `ZeroWord;
		next_inst_in_delayslot_o <= `ZeroWord;
		
		imm <= `ZeroWord;			
		case (op)
		`EXE_SPECIAL_INST: begin // 指令碼是 SPECIAL
		
			case (op2)
			5'b00000: begin
			
				case (op3)
				/// 轉移 (一)
				`EXE_JR: begin
					wreg_o <= `WriteDisable;
					aluop_o <= `EXE_JR_OP;
					alusel_o <= `EXE_RES_JUMP_BRANCH;
					
					reg1_read_o <= 1'b1;
					reg2_read_o <= 1'b0;
					
					link_addr_o <= `ZeroWord;
					branch_target_address_o <= reg1_o;	// 目標位址為 $rs
					branch_flag_o <= `Branch;	// 轉移
					next_inst_in_delayslot_o <= `InDelaySlot;	// 下一條指令位於延遲槽
					
					instvalid <= `InstValid;
				end
				`EXE_JALR: begin
					wreg_o <= `WriteEnable;
					aluop_o <= `EXE_JALR_OP;
					alusel_o <= `EXE_RES_JUMP_BRANCH;
					
					reg1_read_o <= 1'b1;
					reg2_read_o <= 1'b0;
					
					wd_o <= inst_i[15:11];	// 目標暫存器位址為 rd
					link_addr_o <= pc_plus_8;	// $rd 存放 pc + 8
					
					branch_flag_o <= `Branch;
					branch_target_address_o <= reg1_o;	// 轉移目標位址
					
					next_inst_in_delayslot_o <= `InDelaySlot;
					
					instvalid <= `InstValid;
					
				end
				/// 除法
				`EXE_DIV: begin
					wreg_o <= `WriteDisable;
					aluop_o <= `EXE_DIV_OP;
					reg1_read_o <= 1'b1;
					reg2_read_o <= 1'b1;
					instvalid <= `InstValid;
				end
				`EXE_DIVU: begin
					wreg_o <= `WriteDisable;
					aluop_o <= `EXE_DIVU_OP;
					reg1_read_o <= 1'b1;
					reg2_read_o <= 1'b1;
					instvalid <= `InstValid;
				end			
				/// 算數
				`EXE_SLT: begin
					wreg_o <= `WriteEnable;
					aluop_o <= `EXE_SLT_OP;
					alusel_o <= `EXE_RES_ARITHMETIC;
					
					reg1_read_o <= 1'b1;
					reg2_read_o <= 1'b1;
					
					instvalid <= `InstValid;
				end
				`EXE_SLTU: begin
					wreg_o <= `WriteEnable;
					aluop_o <= `EXE_SLTU_OP;
					alusel_o <= `EXE_RES_ARITHMETIC;
					
					reg1_read_o <= 1'b1;
					reg2_read_o <= 1'b1;
					
					instvalid <= `InstValid;
					
				end
				`EXE_ADD: begin
					wreg_o <= `WriteEnable;
					aluop_o <= `EXE_ADD_OP;
					alusel_o <= `EXE_RES_ARITHMETIC;
					
					reg1_read_o <= 1'b1;
					reg2_read_o <= 1'b1;
					
					instvalid <= `InstValid;
				end
				`EXE_ADDU: begin
					wreg_o <= `WriteEnable;
					aluop_o <= `EXE_ADDU_OP;
					alusel_o <= `EXE_RES_ARITHMETIC;
					
					reg1_read_o <= 1'b1;
					reg2_read_o <= 1'b1;
					
					instvalid <= `InstValid;
				end
				`EXE_SUB: begin
					wreg_o <= `WriteEnable;
					aluop_o <= `EXE_SUB_OP;
					alusel_o <= `EXE_RES_ARITHMETIC;
					
					reg1_read_o <= 1'b1;
					reg2_read_o <= 1'b1;
					
					instvalid <= `InstValid;
				end
				`EXE_SUBU: begin
					wreg_o <= `WriteEnable;
					aluop_o <= `EXE_SUBU_OP;
					alusel_o <= `EXE_RES_ARITHMETIC;
					
					reg1_read_o <= 1'b1;
					reg2_read_o <= 1'b1;
					
					instvalid <= `InstValid;
				end
				`EXE_MULT: begin
					wreg_o <= `WriteDisable; // 不修改通用暫存器 (要寫到HILO暫存器)
					
					//MULT MULTU 沒有要寫回 Regfile 所以沒有對應的 AluSel
					aluop_o <= `EXE_MULT_OP;
					
					reg1_read_o <= 1'b1;
					reg2_read_o <= 1'b1;
					
					instvalid <= `InstValid;
				end
				`EXE_MULTU: begin
					wreg_o <= `WriteDisable; // 不修改通用暫存器 (要寫到HILO暫存器)
					
					//MULT MULTU 沒有要寫回 Regfile 所以沒有對應的 AluSel
					aluop_o <= `EXE_MULTU_OP;
					
					reg1_read_o <= 1'b1;
					reg2_read_o <= 1'b1;
					
					instvalid <= `InstValid;
				end
				/// 邏輯
				`EXE_OR: begin
					wreg_o <= `WriteEnable;
					
					reg1_read_o <= 1'b1;
					reg2_read_o <= 1'b1;
					
					aluop_o <= `EXE_OR_OP;
					alusel_o <= `EXE_RES_LOGIC;
					
					instvalid <= `InstValid;
				end
				`EXE_AND: begin
					wreg_o <= `WriteEnable;
					
					reg1_read_o <= 1'b1;
					reg2_read_o <= 1'b1;
					
					aluop_o <= `EXE_AND_OP;
					alusel_o <= `EXE_RES_LOGIC;
					
					instvalid <= `InstValid;
				end
				`EXE_XOR: begin
					wreg_o <= `WriteEnable;
					
					reg1_read_o <= 1'b1;
					reg2_read_o <= 1'b1;
					
					aluop_o <= `EXE_XOR_OP;
					alusel_o <= `EXE_RES_LOGIC;
					
					instvalid <= `InstValid;
				end
				`EXE_NOR: begin
					wreg_o <= `WriteEnable;
					
					reg1_read_o <= 1'b1;
					reg2_read_o <= 1'b1;
					
					aluop_o <= `EXE_NOR_OP;
					alusel_o <= `EXE_RES_LOGIC;
					
					instvalid <= `InstValid;
				end
				`EXE_SLLV: begin
					wreg_o <= `WriteEnable;
					
					reg1_read_o <= 1'b1;
					reg2_read_o <= 1'b1;
					
					aluop_o <= `EXE_SLL_OP;	// SLL
					alusel_o <= `EXE_RES_SHIFT;
					
					instvalid <= `InstValid;
				end
				`EXE_SRLV: begin
					wreg_o <= `WriteEnable;
					
					reg1_read_o <= 1'b1;
					reg2_read_o <= 1'b1;
					
					aluop_o <= `EXE_SRL_OP;	// SRL
					alusel_o <= `EXE_RES_SHIFT;
					
					instvalid <= `InstValid;
				end
				`EXE_SRAV: begin
					wreg_o <= `WriteEnable;
					
					reg1_read_o <= 1'b1;
					reg2_read_o <= 1'b1;
					
					aluop_o <= `EXE_SRA_OP;	// SRA
					alusel_o <= `EXE_RES_SHIFT;
					
					instvalid <= `InstValid;
				end
				`EXE_SYNC: begin
					wreg_o <= `WriteDisable;
					
					reg1_read_o <= 1'b0;
					reg2_read_o <= 1'b1;
					
					aluop_o <= `EXE_NOP_OP;
					alusel_o <= `EXE_RES_NOP;
					
					instvalid <= `InstValid;
				end			
				/// 移動
				`EXE_MFHI: begin
					wreg_o <= `WriteEnable;
					
					aluop_o <= `EXE_MFHI_OP;
					alusel_o <= `EXE_RES_MOVE;
					
					// 不是從 Regfile 讀值
					reg1_read_o <= 1'b0;
					reg2_read_o <= 1'b0;
					
					instvalid = `InstValid;
					
					
				end
				`EXE_MFLO: begin
					wreg_o <= `WriteEnable;
					
					aluop_o <= `EXE_MFLO_OP;
					alusel_o <= `EXE_RES_MOVE;
					
					// 不是從 Regfile 讀值
					reg1_read_o <= 1'b0;
					reg2_read_o <= 1'b0;
					
					instvalid = `InstValid;
				end
				`EXE_MTHI: begin
					wreg_o <= `WriteDisable; /// 不用修改通用暫存器 (要寫到HILO暫存器)
					// MTHI MTLO 沒有要寫回 Regfile 所以沒有對應的 AluSel
					aluop_o <= `EXE_MTHI_OP;
					
					// 要從 Regfile 讀 $rs
					reg1_read_o <= 1'b1;
					reg2_read_o <= 1'b0;
					
					instvalid = `InstValid;
				end
				`EXE_MTLO: begin
					wreg_o <= `WriteDisable; /// 不用修改通用暫存器 (要寫到HILO暫存器)
					// MTHI MTLO 沒有要寫回 Regfile 所以沒有對應的 AluSel
					aluop_o <= `EXE_MTLO_OP;
					
					// 要從 Regfile 讀 $rs
					reg1_read_o <= 1'b1;
					reg2_read_o <= 1'b0;
					
					instvalid = `InstValid;
				end
				`EXE_MOVN: begin

					aluop_o <= `EXE_MOVN_OP;
					alusel_o <= `EXE_RES_MOVE;
					
					// 要從 Regfile 讀 $rs $rt
					reg1_read_o <= 1'b1;
					reg2_read_o <= 1'b1;
					
					instvalid = `InstValid;
					
					if (reg2_o != `ZeroWord) begin
						wreg_o <= `WriteEnable;
					end
					else begin
						wreg_o <= `WriteDisable;
					end
				end
				`EXE_MOVZ: begin
					
					aluop_o <= `EXE_MOVZ_OP;
					alusel_o <= `EXE_RES_MOVE;
					
					// 要從 Regfile 讀 $rs $rt
					reg1_read_o <= 1'b1;
					reg2_read_o <= 1'b1;
					
					instvalid = `InstValid;
					
					if (reg2_o == `ZeroWord) begin
						wreg_o <= `WriteEnable;
					end
					else begin
						wreg_o <= `WriteDisable;
					end
					
				end
				default: begin
				end
				endcase // end cese op3
				
			end
			default: begin
			end
			endcase // end case op2
		end	
		
		`EXE_SPECIAL2_INST: begin
			case (op3)
			// 累進指令 (都是寫進 HILO)
			`EXE_MADD: begin
				aluop_o <= `EXE_MADD_OP;
				
				wreg_o <= `WriteDisable;
				reg1_read_o <= 1'b1;
				reg2_read_o <= 1'b1;
				
				instvalid <= `InstValid;
			end
			`EXE_MADDU:begin
				aluop_o <= `EXE_MADDU_OP;
				
				wreg_o <= `WriteDisable;
				reg1_read_o <= 1'b1;
				reg2_read_o <= 1'b1;
				
				instvalid <= `InstValid;
			end
			`EXE_MSUB:begin
				aluop_o <= `EXE_MSUB_OP;
				
				wreg_o <= `WriteDisable;
				reg1_read_o <= 1'b1;
				reg2_read_o <= 1'b1;
				
				instvalid <= `InstValid;
			end
			`EXE_MSUBU:begin
				aluop_o <= `EXE_MSUBU_OP;
				
				wreg_o <= `WriteDisable;
				reg1_read_o <= 1'b1;
				reg2_read_o <= 1'b1;
				
				instvalid <= `InstValid;
			end
			
			// 比較和乘法指令
			`EXE_CLZ: begin
				aluop_o <= `EXE_CLZ_OP;
				alusel_o <= `EXE_RES_ARITHMETIC;
				
				wreg_o <= `WriteEnable;
				
				reg1_read_o <= 1'b1;
				reg2_read_o <= 1'b0;
				
				// 立即值預設為0 (初始值),所以不再設 imm!
				
				instvalid <= `InstValid;
			end
			`EXE_CLO: begin
				aluop_o <= `EXE_CLO_OP;
				alusel_o <= `EXE_RES_ARITHMETIC;
				
				wreg_o <= `WriteEnable;	
				
				reg1_read_o <= 1'b1;
				reg2_read_o <= 1'b0;
				
				// 立即值預設為0 (初始值),所以不再設 imm!
				
				instvalid <= `InstValid;
				
			end
			`EXE_MUL: begin
				aluop_o <= `EXE_MUL_OP;
				alusel_o <= `EXE_RES_MUL;
				
				wreg_o <= `WriteEnable;
				
				reg1_read_o <= 1'b1;
				reg2_read_o <= 1'b1;
				
				instvalid <= `InstValid;
				
			end
			default: begin
			end
			endcase // end case special2 op3
		end
		
		/// 轉移 (三)
		`EXE_REGIMM_INST: begin
            case (op4)
            `EXE_BGEZ: begin
                wreg_o <= `WriteDisable;
                aluop_o <= `EXE_BGEZ_OP;
                alusel_o <= `EXE_RES_JUMP_BRANCH;
                
                reg1_read_o <= 1'b1;
                reg2_read_o <= 1'b0;
                    
                if(reg1_o[31] == 1'b0) begin
                    branch_target_address_o <= pc_plus_4 + imm_sll2_signedext;
                    branch_flag_o <= `Branch;
                    next_inst_in_delayslot_o <= `InDelaySlot;		  	
                end
                
                instvalid <= `InstValid;
            end
            `EXE_BGEZAL: begin
                wreg_o <= `WriteEnable;
                aluop_o <= `EXE_BGEZAL_OP;
                alusel_o <= `EXE_RES_JUMP_BRANCH;
                
                reg1_read_o <= 1'b1;
                reg2_read_o <= 1'b0;
                
                link_addr_o <= pc_plus_8; 
                wd_o <= 5'b11111;
                
                if(reg1_o[31] == 1'b0) begin
                    branch_target_address_o <= pc_plus_4 + imm_sll2_signedext;
                    branch_flag_o <= `Branch;
                    next_inst_in_delayslot_o <= `InDelaySlot;
                end
                
                instvalid <= `InstValid;
            end
            `EXE_BLTZ: begin
                wreg_o <= `WriteDisable;
                aluop_o <= `EXE_BGEZAL_OP;
                alusel_o <= `EXE_RES_JUMP_BRANCH;
                
                reg1_read_o <= 1'b1;
                reg2_read_o <= 1'b0;
                
                if(reg1_o[31] == 1'b1) begin
                    branch_target_address_o <= pc_plus_4 + imm_sll2_signedext;
                    branch_flag_o <= `Branch;
                    next_inst_in_delayslot_o <= `InDelaySlot;		  	
                end
                
                instvalid <= `InstValid;
            end
            `EXE_BLTZAL:		begin
                wreg_o <= `WriteEnable;
                aluop_o <= `EXE_BGEZAL_OP;
                alusel_o <= `EXE_RES_JUMP_BRANCH;
                
                reg1_read_o <= 1'b1;
                reg2_read_o <= 1'b0;
                link_addr_o <= pc_plus_8;	
                wd_o <= 5'b11111;
                
                if(reg1_o[31] == 1'b1) begin
                    branch_target_address_o <= pc_plus_4 + imm_sll2_signedext;
                    branch_flag_o <= `Branch;
                    next_inst_in_delayslot_o <= `InDelaySlot;
                end
                
                instvalid <= `InstValid;
            end
            default:	begin
            end
            endcase
		end
		/// 轉移 (二)
		`EXE_J: begin
			wreg_o <= `WriteDisable;
			
			aluop_o <= `EXE_J_OP;
			alusel_o <= `EXE_RES_JUMP_BRANCH;
			
			reg1_read_o <= 1'b0;
			reg2_read_o <= 1'b0;
			
			link_addr_o <= `ZeroWord;
			
			branch_flag_o <= `Branch;
			branch_target_address_o <= {pc_plus_4[31:28],inst_i[25:0],2'b00};
			
			next_inst_in_delayslot_o <= `InDelaySlot;
			
			instvalid <= `InstValid;
			
		end
		`EXE_JAL: begin
			wreg_o <= `WriteEnable;
			aluop_o <= `EXE_JAL_OP;
			alusel_o <= `EXE_RES_JUMP_BRANCH;
			
			reg1_read_o <= 1'b0;
			reg2_read_o <= 1'b0;
			
			wd_o <= 5'b11111;	// 目標暫存器為 31 號暫存器
			link_addr_o <= pc_plus_8; // 31 號暫存器保存 pc + 8
			
			branch_flag_o <= `Branch;
			branch_target_address_o <= {pc_plus_4[31:28],inst_i[25:0],2'b00};
			
			next_inst_in_delayslot_o <= `InDelaySlot;
			
			instvalid <= `InstValid;
		end
		`EXE_BEQ: begin
            wreg_o <= `WriteDisable;
            aluop_o <= `EXE_BEQ_OP;
            alusel_o <= `EXE_RES_JUMP_BRANCH;
            
            reg1_read_o <= 1'b1;
            reg2_read_o <= 1'b1;
              
            if (reg1_o == reg2_o) begin
              branch_target_address_o <= pc_plus_4 + imm_sll2_signedext;
              branch_flag_o <= `Branch;
              next_inst_in_delayslot_o <= `InDelaySlot;
            end
		end
		`EXE_BGTZ: begin
            wreg_o <= `WriteDisable;
            aluop_o <= `EXE_BGTZ_OP;
            alusel_o <= `EXE_RES_JUMP_BRANCH;
            
            reg1_read_o <= 1'b1;
            reg2_read_o <= 1'b0;
            
            if((reg1_o[31] == 1'b0) || (reg1_o == `ZeroWord)) begin
                branch_target_address_o <= pc_plus_4 + imm_sll2_signedext;
                branch_flag_o <= `Branch;
                next_inst_in_delayslot_o <= `InDelaySlot;		  	
            end
            instvalid <= `InstValid;
		end
		`EXE_BLEZ: begin
            wreg_o <= `WriteDisable;
            aluop_o <= `EXE_BLEZ_OP;
            alusel_o <= `EXE_RES_JUMP_BRANCH;
            
            reg1_read_o <= 1'b1;
            reg2_read_o <= 1'b0;
            
            if((reg1_o[31] == 1'b1) || (reg1_o == `ZeroWord)) begin
                branch_target_address_o <= pc_plus_4 + imm_sll2_signedext;
                branch_flag_o <= `Branch;
                next_inst_in_delayslot_o <= `InDelaySlot;		  	
            end
            
            instvalid <= `InstValid;	
		end
		`EXE_BNE: begin
            wreg_o <= `WriteDisable;
            aluop_o <= `EXE_BLEZ_OP;
            alusel_o <= `EXE_RES_JUMP_BRANCH;
            
            reg1_read_o <= 1'b1;
            reg2_read_o <= 1'b1;
            
            if(reg1_o != reg2_o) begin
                branch_target_address_o <= pc_plus_4 + imm_sll2_signedext;
                branch_flag_o <= `Branch;
                next_inst_in_delayslot_o <= `InDelaySlot;		  	
            end
            
            instvalid <= `InstValid;
		end
		
		// 算數 (立即)
		`EXE_SLTI: begin
			aluop_o <= `EXE_SLT_OP;
			alusel_o <= `EXE_RES_ARITHMETIC;
			
			// 要寫入目標暫存器，但目標暫存器位址為 rt 非 rd!
			wreg_o <= `WriteEnable;
			wd_o <= inst_i[20:16];
			
			reg1_read_o <= 1'b1;
			reg2_read_o <= 1'b0;
			
			imm <= {{16{inst_i[15]}} , inst_i[15:0]}; // 立即值做符號擴展
			
			instvalid <= `InstValid;
		end
		`EXE_SLTIU:begin
			aluop_o <= `EXE_SLTU_OP;
			alusel_o <= `EXE_RES_ARITHMETIC;
			
			// 要寫入目標暫存器，但目標暫存器位址為 rt 非 rd!
			wreg_o <= `WriteEnable;
			wd_o <= inst_i[20:16];
			
			reg1_read_o <= 1'b1;
			reg2_read_o <= 1'b0;
			
			imm <= {{16{inst_i[15]}} , inst_i[15:0]}; // 立即值做符號擴展
			
			instvalid <= `InstValid;
			
		end
		`EXE_ADDI: begin
			aluop_o <= `EXE_ADDI_OP;
			alusel_o <= `EXE_RES_ARITHMETIC;
			
			// 要寫入目標暫存器，但目標暫存器位址為 rt 非 rd!
			wreg_o <= `WriteEnable;
			wd_o <= inst_i[20:16];
			
			reg1_read_o <= 1'b1;
			reg2_read_o <= 1'b0;
			
			imm <= {{16{inst_i[15]}} , inst_i[15:0]}; // 立即值做符號擴展
			
			instvalid <= `InstValid;
		end
		`EXE_ADDIU: begin
			aluop_o <= `EXE_ADDIU_OP;
			alusel_o <= `EXE_RES_ARITHMETIC;
			
			// 要寫入目標暫存器，但目標暫存器位址為 rt 非 rd!
			wreg_o <= `WriteEnable;
			wd_o <= inst_i[20:16];
			
			reg1_read_o <= 1'b1;
			reg2_read_o <= 1'b0;
			
			imm <= {{16{inst_i[15]}} , inst_i[15:0]}; // 立即值做符號擴展
			
			instvalid <= `InstValid;
		end
		
		// 邏輯 (立即)
		`EXE_ORI: begin
			wreg_o <= `WriteEnable;
			
			reg1_read_o <= 1'b1; // 欲輸出 $rs 作為運算來源
			reg2_read_o <= 1'b0; // 欲輸出 inst_i[15:0] 立即值作為運算來源
			
			imm <= {16'h0, inst_i[15:0]}; // zero padding
			
			aluop_o <= `EXE_OR_OP;
			alusel_o <= `EXE_RES_LOGIC;
			
			wd_o <= inst_i[20:16]; // 目標暫存器位址並非存放在 rd 而是 rt!
			instvalid <= `InstValid;
		end
		`EXE_ANDI: begin
			wreg_o <= `WriteEnable;
			
			reg1_read_o <= 1'b1; // 欲輸出 $rs 作為運算來源
			reg2_read_o <= 1'b0; // 欲輸出 inst_i[15:0] 立即值作為運算來源
			
			imm <= {16'h0, inst_i[15:0]}; // zero padding
			
			aluop_o <= `EXE_AND_OP;
			alusel_o <= `EXE_RES_LOGIC;
			
			wd_o <= inst_i[20:16]; // 目標暫存器位址並非存放在 rd 而是 rt!
			instvalid <= `InstValid;
		end
		`EXE_XORI: begin
			wreg_o <= `WriteEnable;
			
			reg1_read_o <= 1'b1; // 欲輸出 $rs 作為運算來源
			reg2_read_o <= 1'b0; // 欲輸出 inst_i[15:0] 立即值作為運算來源
			
			imm <= {16'h0, inst_i[15:0]}; // zero padding
			
			aluop_o <= `EXE_XOR_OP;
			alusel_o <= `EXE_RES_LOGIC;
			
			wd_o <= inst_i[20:16]; // 目標暫存器位址並非存放在 rd 而是 rt!
			instvalid <= `InstValid;
		end
		
		// 移動 (立即)
		`EXE_LUI: begin
			wreg_o <= `WriteEnable;
			
			reg1_read_o <= 1'b1; // rs = 5'b00000
			reg2_read_o <= 1'b0; // 欲輸出 inst_i[15:0] 作為高位的立即值為運算來源
			
			imm <= {inst_i[15:0],16'h0};
			
			wd_o <= inst_i[20:16]; // 目標暫存器位址並非存放在 rd 而是 rt!
			
			aluop_o <= `EXE_OR_OP; // 用 OR 運算即可 (OR $rt , $0 , imm)
			alusel_o <= `EXE_RES_LOGIC;
			
			instvalid <= `InstValid;
		end
		
		//
		`EXE_PREF:begin
			wreg_o <= `WriteDisable;
			aluop_o <= `EXE_NOP_OP;
			alusel_o <= `EXE_RES_NOP;
			reg1_read_o <= 1'b0;
			reg2_read_o <= 1'b0;
			instvalid <= `InstValid;
		end
		default: begin
		end
		endcase

		
		if (inst_i[31:21] == 11'b00000000000) begin
		
			if (op3 == `EXE_SLL) begin
				wreg_o <= `WriteEnable;
				
				aluop_o <= `EXE_SLL_OP;
				alusel_o <= `EXE_RES_SHIFT;
				
				reg1_read_o <= 1'b0; // 欲位移 ra
				reg2_read_o <= 1'b1;
				
				imm[4:0] <= inst_i[10:6]; // 將 imm 設為 ra
				
				instvalid <= `InstValid;
			end
			else if (op3 == `EXE_SRL) begin
				wreg_o <= `WriteEnable;
				
				aluop_o <= `EXE_SRL_OP;
				alusel_o <= `EXE_RES_SHIFT;
				
				reg1_read_o <= 1'b0; // 欲位移 ra
				reg2_read_o <= 1'b1;
				
				imm[4:0] <= inst_i[10:6]; // 將 imm 設為 ra
				
				instvalid <= `InstValid;
			end
			else if (op3 == `EXE_SRA) begin
				wreg_o <= `WriteEnable;
				
				aluop_o <= `EXE_SRA_OP;
				alusel_o <= `EXE_RES_SHIFT;
				
				reg1_read_o <= 1'b0; // 欲位移 ra
				reg2_read_o <= 1'b1; // 欲得到 $rt
				
				imm[4:0] <= inst_i[10:6]; // 將 imm 設為 ra
				
				instvalid <= `InstValid;
			end
			else begin
			end
		end
		else begin
		end
		
		
	end       //if
end         //always
	

// 若 read 1 為可讀， read 2 為不可讀，則 reg1_o 輸出 reg1_data_i；reg2_o 輸出 imm。
always @ (*) begin
	if(rst == `RstEnable) begin
		reg1_o <= `ZeroWord;
	end else if((reg1_read_o == 1'b1) && (ex_wreg_i == 1'b1) && (ex_wd_i == reg1_addr_o)) begin
	/*
	前饋 --
	若 EXE 階段的運算結果要寫回暫存器，且目的暫存器位址相當於當前要讀取 Regfile 的暫存器位址，則直接
	將從 Regfile 讀出的值設為 EXE 階段欲更新的值
	 */
		reg1_o <= ex_wdata_i;
	
	end else if((reg1_read_o == 1'b1) && (mem_wreg_i == 1'b1) && (mem_wd_i == reg1_addr_o)) begin
		reg1_o <= mem_wdata_i;
		
	end else if(reg1_read_o == 1'b1) begin 
		reg1_o <= reg1_data_i;
	end else if(reg1_read_o == 1'b0) begin
		reg1_o <= imm;
	end else begin
		reg1_o <= `ZeroWord;
	end
end

always @ (*) begin
	if(rst == `RstEnable) begin
		reg2_o <= `ZeroWord;
	end else if((reg2_read_o == 1'b1) && (ex_wreg_i == 1'b1) && (ex_wd_i == reg2_addr_o)) begin
	// 若 EXE 階段的運算結果要寫回暫存器，且目的暫存器位址相當於當前要讀取 Regfile 的暫存器位址，則直接
	// 將從 Regfile 讀出的值設為 EXE 階段欲更新的值
		reg2_o <= ex_wdata_i;
	
	end else if((reg2_read_o == 1'b1) && (mem_wreg_i == 1'b1) && (mem_wd_i == reg2_addr_o)) begin
		reg2_o <= mem_wdata_i;
		
		
	end else if(reg2_read_o == 1'b1) begin
		reg2_o <= reg2_data_i;
	end else if(reg2_read_o == 1'b0) begin
		reg2_o <= imm;
	end else begin
		reg2_o <= `ZeroWord;
	end
end

// 輸出 is_in_delayslot_o (當前譯碼指令是否是延遲槽指令)
always @(*) begin
    if(rst == `RstEnable) begin
        is_in_delayslot_o <= `NotInDelaySlot;
    end else begin
        is_in_delayslot_o <= is_in_delayslot_i;		
    end
end
endmodule