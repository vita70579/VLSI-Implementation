`include "defines.v"

module id(

	input wire rst,
	output wire stallreq, // �޽u�Ȱ��H��	
	
	input wire[`InstAddrBus] pc_i, // �s����O����}
	input wire[`InstBus] inst_i, // �ݸѽX�����O

	input wire[`RegBus] reg1_data_i, // �q Regfile Ū�쪺 �Ȧs��1�� 
	input wire[`RegBus] reg2_data_i, // �q Regfile Ū�쪺 �Ȧs��2�� 

	//�e��regfile���H��
	output reg reg1_read_o,
	output reg reg2_read_o,     
	output reg[`RegAddrBus] reg1_addr_o,
	output reg[`RegAddrBus] reg2_addr_o, 	      
	
	//�e����涥�q���H��
	output reg[`AluOpBus] aluop_o, // �b EXE ���q�n���檺�B�� (�ëD�����X�A�ӬO EXE ���q CASE ���s��)
	output reg[`AluSelBus] alusel_o, // ALU ���� (Logic Shift Load...) (�ëD�����X�A�ӬO EXE ���q CASE ���s��)
	output reg[`RegBus] reg1_o, // �q Regfile Ū�쪺 �Ȧs��1�ȡA�Yrs �Ȧs���ȡC
	output reg[`RegBus] reg2_o, // �q Regfile Ū�쪺 �Ȧs��1�ȡA�Yrt �Ȧs���ȡC
	output reg[`RegAddrBus] wd_o, // �ؼмȦs����}
	output reg wreg_o, // read enable
	
	/// �ѨM�ƾڦM�١G�e�X
	// �B�� EXE ���q�����O���B�⵲�G
	input wire ex_wreg_i, // ���涥�q���G�O�_�g�^�Ȧs��
	input wire[`RegBus] ex_wdata_i, // ���涥�q�n�g�^�Ȧs������
	input wire[`RegAddrBus] ex_wd_i, // ���涥�q�n�g�^���ت��Ȧs����}
	
	// �B�� MEM ���q�����O���B�⵲�G
	input wire mem_wreg_i, // MEM ���q���G�O�_�g�^�Ȧs��
	input wire[`RegBus] mem_wdata_i, // MEM ���q�n�g�^�Ȧs������
	input wire[`RegAddrBus] mem_wd_i, // MEM ���q�n�g�^���ت��Ȧs����}
	
	// �ಾ���O
	input wire is_in_delayslot_i,	// ��e�B��Ķ�X���q�����O�O�_��󩵿��
	
	output reg is_in_delayslot_o,	// ��e�B��Ķ�X���q�����O�O�_��󩵿��
	output reg next_inst_in_delayslot_o,	// �U�@���i�JĶ�X���q���O�O�_��󩵿��
	output reg branch_flag_o,	// �O�_�o���ಾ
	output reg[`RegBus] branch_target_address_o,	// �ಾ�ؼЦ�}
	output reg[`RegBus] link_addr_o // �ಾ���O�n�O�s����^��}
	
	
	
);

assign stallreq = `NoStop;

/// ���O�����i�H�̧ǫ��� [31:26][10:6][5:0] ����...
wire[5:0] op = inst_i[31:26]; // op code
wire[4:0] op2 = inst_i[10:6];
wire[5:0] op3 = inst_i[5:0]; // funct
wire[4:0] op4 = inst_i[20:16];

reg[`RegBus] imm; // �ߧY��
reg instvalid; // ���O�O�_����

// �ಾ���O
wire [`RegBus] pc_plus_8;	// �O�s��e���O��ĤG�����O��}
wire [`RegBus] pc_plus_4;	// �O�s��e���O��@�����O��}
wire [`RegBus] imm_sll2_signedext; // �Ҧ�������O���ಾ�ؼЦa�}��: �u(signed_extend){offset,00}�v + (pc+4)

assign pc_plus_4 = pc_i + 4 ;
assign pc_plus_8 = pc_i + 8 ;
assign imm_sll2_signedext = {{14{inst_i[15]}},inst_i[15:0],2'b00};	// �����ಾ���O�� offset �����O�� 16 bits.
 
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
		
		// �ಾ���O
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
		reg1_addr_o <= inst_i[25:21]; // �q Regfile Ū rs �Ȧs����}
		reg2_addr_o <= inst_i[20:16]; // �q Regfile Ū rt �Ȧs����}
		
		// �ಾ���O
		link_addr_o <= `ZeroWord;
		branch_target_address_o <= `ZeroWord;
		branch_flag_o <= `ZeroWord;
		next_inst_in_delayslot_o <= `ZeroWord;
		
		imm <= `ZeroWord;			
		case (op)
		`EXE_SPECIAL_INST: begin // ���O�X�O SPECIAL
		
			case (op2)
			5'b00000: begin
			
				case (op3)
				/// �ಾ (�@)
				`EXE_JR: begin
					wreg_o <= `WriteDisable;
					aluop_o <= `EXE_JR_OP;
					alusel_o <= `EXE_RES_JUMP_BRANCH;
					
					reg1_read_o <= 1'b1;
					reg2_read_o <= 1'b0;
					
					link_addr_o <= `ZeroWord;
					branch_target_address_o <= reg1_o;	// �ؼЦ�}�� $rs
					branch_flag_o <= `Branch;	// �ಾ
					next_inst_in_delayslot_o <= `InDelaySlot;	// �U�@�����O��󩵿��
					
					instvalid <= `InstValid;
				end
				`EXE_JALR: begin
					wreg_o <= `WriteEnable;
					aluop_o <= `EXE_JALR_OP;
					alusel_o <= `EXE_RES_JUMP_BRANCH;
					
					reg1_read_o <= 1'b1;
					reg2_read_o <= 1'b0;
					
					wd_o <= inst_i[15:11];	// �ؼмȦs����}�� rd
					link_addr_o <= pc_plus_8;	// $rd �s�� pc + 8
					
					branch_flag_o <= `Branch;
					branch_target_address_o <= reg1_o;	// �ಾ�ؼЦ�}
					
					next_inst_in_delayslot_o <= `InDelaySlot;
					
					instvalid <= `InstValid;
					
				end
				/// ���k
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
				/// ���
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
					wreg_o <= `WriteDisable; // ���ק�q�μȦs�� (�n�g��HILO�Ȧs��)
					
					//MULT MULTU �S���n�g�^ Regfile �ҥH�S�������� AluSel
					aluop_o <= `EXE_MULT_OP;
					
					reg1_read_o <= 1'b1;
					reg2_read_o <= 1'b1;
					
					instvalid <= `InstValid;
				end
				`EXE_MULTU: begin
					wreg_o <= `WriteDisable; // ���ק�q�μȦs�� (�n�g��HILO�Ȧs��)
					
					//MULT MULTU �S���n�g�^ Regfile �ҥH�S�������� AluSel
					aluop_o <= `EXE_MULTU_OP;
					
					reg1_read_o <= 1'b1;
					reg2_read_o <= 1'b1;
					
					instvalid <= `InstValid;
				end
				/// �޿�
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
				/// ����
				`EXE_MFHI: begin
					wreg_o <= `WriteEnable;
					
					aluop_o <= `EXE_MFHI_OP;
					alusel_o <= `EXE_RES_MOVE;
					
					// ���O�q Regfile Ū��
					reg1_read_o <= 1'b0;
					reg2_read_o <= 1'b0;
					
					instvalid = `InstValid;
					
					
				end
				`EXE_MFLO: begin
					wreg_o <= `WriteEnable;
					
					aluop_o <= `EXE_MFLO_OP;
					alusel_o <= `EXE_RES_MOVE;
					
					// ���O�q Regfile Ū��
					reg1_read_o <= 1'b0;
					reg2_read_o <= 1'b0;
					
					instvalid = `InstValid;
				end
				`EXE_MTHI: begin
					wreg_o <= `WriteDisable; /// ���έק�q�μȦs�� (�n�g��HILO�Ȧs��)
					// MTHI MTLO �S���n�g�^ Regfile �ҥH�S�������� AluSel
					aluop_o <= `EXE_MTHI_OP;
					
					// �n�q Regfile Ū $rs
					reg1_read_o <= 1'b1;
					reg2_read_o <= 1'b0;
					
					instvalid = `InstValid;
				end
				`EXE_MTLO: begin
					wreg_o <= `WriteDisable; /// ���έק�q�μȦs�� (�n�g��HILO�Ȧs��)
					// MTHI MTLO �S���n�g�^ Regfile �ҥH�S�������� AluSel
					aluop_o <= `EXE_MTLO_OP;
					
					// �n�q Regfile Ū $rs
					reg1_read_o <= 1'b1;
					reg2_read_o <= 1'b0;
					
					instvalid = `InstValid;
				end
				`EXE_MOVN: begin

					aluop_o <= `EXE_MOVN_OP;
					alusel_o <= `EXE_RES_MOVE;
					
					// �n�q Regfile Ū $rs $rt
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
					
					// �n�q Regfile Ū $rs $rt
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
			// �ֶi���O (���O�g�i HILO)
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
			
			// ����M���k���O
			`EXE_CLZ: begin
				aluop_o <= `EXE_CLZ_OP;
				alusel_o <= `EXE_RES_ARITHMETIC;
				
				wreg_o <= `WriteEnable;
				
				reg1_read_o <= 1'b1;
				reg2_read_o <= 1'b0;
				
				// �ߧY�ȹw�]��0 (��l��),�ҥH���A�] imm!
				
				instvalid <= `InstValid;
			end
			`EXE_CLO: begin
				aluop_o <= `EXE_CLO_OP;
				alusel_o <= `EXE_RES_ARITHMETIC;
				
				wreg_o <= `WriteEnable;	
				
				reg1_read_o <= 1'b1;
				reg2_read_o <= 1'b0;
				
				// �ߧY�ȹw�]��0 (��l��),�ҥH���A�] imm!
				
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
		
		/// �ಾ (�T)
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
		/// �ಾ (�G)
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
			
			wd_o <= 5'b11111;	// �ؼмȦs���� 31 ���Ȧs��
			link_addr_o <= pc_plus_8; // 31 ���Ȧs���O�s pc + 8
			
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
		
		// ��� (�ߧY)
		`EXE_SLTI: begin
			aluop_o <= `EXE_SLT_OP;
			alusel_o <= `EXE_RES_ARITHMETIC;
			
			// �n�g�J�ؼмȦs���A���ؼмȦs����}�� rt �D rd!
			wreg_o <= `WriteEnable;
			wd_o <= inst_i[20:16];
			
			reg1_read_o <= 1'b1;
			reg2_read_o <= 1'b0;
			
			imm <= {{16{inst_i[15]}} , inst_i[15:0]}; // �ߧY�Ȱ��Ÿ��X�i
			
			instvalid <= `InstValid;
		end
		`EXE_SLTIU:begin
			aluop_o <= `EXE_SLTU_OP;
			alusel_o <= `EXE_RES_ARITHMETIC;
			
			// �n�g�J�ؼмȦs���A���ؼмȦs����}�� rt �D rd!
			wreg_o <= `WriteEnable;
			wd_o <= inst_i[20:16];
			
			reg1_read_o <= 1'b1;
			reg2_read_o <= 1'b0;
			
			imm <= {{16{inst_i[15]}} , inst_i[15:0]}; // �ߧY�Ȱ��Ÿ��X�i
			
			instvalid <= `InstValid;
			
		end
		`EXE_ADDI: begin
			aluop_o <= `EXE_ADDI_OP;
			alusel_o <= `EXE_RES_ARITHMETIC;
			
			// �n�g�J�ؼмȦs���A���ؼмȦs����}�� rt �D rd!
			wreg_o <= `WriteEnable;
			wd_o <= inst_i[20:16];
			
			reg1_read_o <= 1'b1;
			reg2_read_o <= 1'b0;
			
			imm <= {{16{inst_i[15]}} , inst_i[15:0]}; // �ߧY�Ȱ��Ÿ��X�i
			
			instvalid <= `InstValid;
		end
		`EXE_ADDIU: begin
			aluop_o <= `EXE_ADDIU_OP;
			alusel_o <= `EXE_RES_ARITHMETIC;
			
			// �n�g�J�ؼмȦs���A���ؼмȦs����}�� rt �D rd!
			wreg_o <= `WriteEnable;
			wd_o <= inst_i[20:16];
			
			reg1_read_o <= 1'b1;
			reg2_read_o <= 1'b0;
			
			imm <= {{16{inst_i[15]}} , inst_i[15:0]}; // �ߧY�Ȱ��Ÿ��X�i
			
			instvalid <= `InstValid;
		end
		
		// �޿� (�ߧY)
		`EXE_ORI: begin
			wreg_o <= `WriteEnable;
			
			reg1_read_o <= 1'b1; // ����X $rs �@���B��ӷ�
			reg2_read_o <= 1'b0; // ����X inst_i[15:0] �ߧY�ȧ@���B��ӷ�
			
			imm <= {16'h0, inst_i[15:0]}; // zero padding
			
			aluop_o <= `EXE_OR_OP;
			alusel_o <= `EXE_RES_LOGIC;
			
			wd_o <= inst_i[20:16]; // �ؼмȦs����}�ëD�s��b rd �ӬO rt!
			instvalid <= `InstValid;
		end
		`EXE_ANDI: begin
			wreg_o <= `WriteEnable;
			
			reg1_read_o <= 1'b1; // ����X $rs �@���B��ӷ�
			reg2_read_o <= 1'b0; // ����X inst_i[15:0] �ߧY�ȧ@���B��ӷ�
			
			imm <= {16'h0, inst_i[15:0]}; // zero padding
			
			aluop_o <= `EXE_AND_OP;
			alusel_o <= `EXE_RES_LOGIC;
			
			wd_o <= inst_i[20:16]; // �ؼмȦs����}�ëD�s��b rd �ӬO rt!
			instvalid <= `InstValid;
		end
		`EXE_XORI: begin
			wreg_o <= `WriteEnable;
			
			reg1_read_o <= 1'b1; // ����X $rs �@���B��ӷ�
			reg2_read_o <= 1'b0; // ����X inst_i[15:0] �ߧY�ȧ@���B��ӷ�
			
			imm <= {16'h0, inst_i[15:0]}; // zero padding
			
			aluop_o <= `EXE_XOR_OP;
			alusel_o <= `EXE_RES_LOGIC;
			
			wd_o <= inst_i[20:16]; // �ؼмȦs����}�ëD�s��b rd �ӬO rt!
			instvalid <= `InstValid;
		end
		
		// ���� (�ߧY)
		`EXE_LUI: begin
			wreg_o <= `WriteEnable;
			
			reg1_read_o <= 1'b1; // rs = 5'b00000
			reg2_read_o <= 1'b0; // ����X inst_i[15:0] �@�����쪺�ߧY�Ȭ��B��ӷ�
			
			imm <= {inst_i[15:0],16'h0};
			
			wd_o <= inst_i[20:16]; // �ؼмȦs����}�ëD�s��b rd �ӬO rt!
			
			aluop_o <= `EXE_OR_OP; // �� OR �B��Y�i (OR $rt , $0 , imm)
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
				
				reg1_read_o <= 1'b0; // ���첾 ra
				reg2_read_o <= 1'b1;
				
				imm[4:0] <= inst_i[10:6]; // �N imm �]�� ra
				
				instvalid <= `InstValid;
			end
			else if (op3 == `EXE_SRL) begin
				wreg_o <= `WriteEnable;
				
				aluop_o <= `EXE_SRL_OP;
				alusel_o <= `EXE_RES_SHIFT;
				
				reg1_read_o <= 1'b0; // ���첾 ra
				reg2_read_o <= 1'b1;
				
				imm[4:0] <= inst_i[10:6]; // �N imm �]�� ra
				
				instvalid <= `InstValid;
			end
			else if (op3 == `EXE_SRA) begin
				wreg_o <= `WriteEnable;
				
				aluop_o <= `EXE_SRA_OP;
				alusel_o <= `EXE_RES_SHIFT;
				
				reg1_read_o <= 1'b0; // ���첾 ra
				reg2_read_o <= 1'b1; // ���o�� $rt
				
				imm[4:0] <= inst_i[10:6]; // �N imm �]�� ra
				
				instvalid <= `InstValid;
			end
			else begin
			end
		end
		else begin
		end
		
		
	end       //if
end         //always
	

// �Y read 1 ���iŪ�A read 2 �����iŪ�A�h reg1_o ��X reg1_data_i�Freg2_o ��X imm�C
always @ (*) begin
	if(rst == `RstEnable) begin
		reg1_o <= `ZeroWord;
	end else if((reg1_read_o == 1'b1) && (ex_wreg_i == 1'b1) && (ex_wd_i == reg1_addr_o)) begin
	/*
	�e�X --
	�Y EXE ���q���B�⵲�G�n�g�^�Ȧs���A�B�ت��Ȧs����}�۷���e�nŪ�� Regfile ���Ȧs����}�A�h����
	�N�q Regfile Ū�X���ȳ]�� EXE ���q����s����
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
	// �Y EXE ���q���B�⵲�G�n�g�^�Ȧs���A�B�ت��Ȧs����}�۷���e�nŪ�� Regfile ���Ȧs����}�A�h����
	// �N�q Regfile Ū�X���ȳ]�� EXE ���q����s����
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

// ��X is_in_delayslot_o (��eĶ�X���O�O�_�O����ѫ��O)
always @(*) begin
    if(rst == `RstEnable) begin
        is_in_delayslot_o <= `NotInDelaySlot;
    end else begin
        is_in_delayslot_o <= is_in_delayslot_i;		
    end
end
endmodule