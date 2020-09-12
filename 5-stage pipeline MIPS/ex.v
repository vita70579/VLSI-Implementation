`include "defines.v"

module ex(

	input wire rst,
	output reg stallreq,
	
	// �e����涥�q���H��
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
	HI LO �Ҳ�
	   ���o HI,LO ��
	   ��X HI,LO ��
	*/
	input wire[`RegBus] hi_i,
	input wire[`RegBus] lo_i,
	output reg whilo_o,
	output reg[`RegBus] hi_o,
	output reg[`RegBus] lo_o,
	
	/// �ѨM mfhi,mflo �ƾڦM�ٰ��D (�]���A�� Regfile �ҥH�e�X�� EXE ���q)
	
	input wire mem_whilo_i, // MEM ���q�O�_�n�g�J HI LO
	input wire[`RegBus] mem_hi_i, // ���g�J HI ���ƾ�
	input wire[`RegBus] mem_lo_i, // ���g�J LO ���ƾ�
	
	input wire wb_whilo_i, // WB ���q�O�_�n�g�J HI LO
	input wire[`RegBus] wb_hi_i, // ���g�J HI ���ƾ�
	input wire[`RegBus] wb_lo_i, // ���g�J LO ���ƾ�
	
	/*
	�Ω�ֶi�B�⪺�ݤf
	(a) �n�N�Ĥ@�Ӱ���g���o�쪺���k���G�s��� ex/mem ���q���Ȧs��
	(b) �b�ĤG�Ӷ��q�ɨ��^�i���S�[
	(c) �n�p�ư���g��
	*/
	
	output reg[`DoubleRegBus] hilo_temp_o,
	output reg[1:0] cnt_o,
	input wire[`DoubleRegBus] hilo_temp_i,
	input wire[1:0] cnt_i,
	
	// ���k���O�ݤf
	input wire[`DoubleRegBus] div_result_i,
	input wire div_ready_i,
	
	output reg[`RegBus] div_opdata1_o,
	output reg[`RegBus] div_opdata2_o,
	output reg div_start_o,
	output reg signed_div_o,
	
	// �ಾ���O�T��
	input wire[`RegBus] link_address_i,
	input wire is_in_delayslot_i
);

reg[`RegBus] logicout; // �O�s�޿�B�⵲�G
reg[`RegBus] shiftres; // �O�s�첾�B�⵲�G
reg[`RegBus] moveres; // �O�s���ʹB�⵲�G
reg[`RegBus] arithmeticres; // �O�s��ƹB�⵲�G

reg[`RegBus] HI; // �O�s HI �Ȧs���̷s��
reg[`RegBus] LO; // �O�s LO �Ȧs���̷s��

// ��N�B��һ�
wire ov_sum; // �O�s���챡��
wire reg1_eq_reg2;
wire reg1_lt_reg2;
wire[`RegBus] reg2_i_mux; // �O�s��J���ĤG�Ӿާ@�ƪ��ɼ�
wire[`RegBus] reg1_i_not; // �O�s��J���Ĥ@�Ӿާ@�ƪ���
wire[`RegBus] result_sum; // �O�s�[�k���G
wire[`RegBus] opdata1_mult; // ���k�����Q����
wire[`RegBus] opdata2_mult; // ���k��������
wire[`DoubleRegBus] hilo_temp; // �{�ɭ��k���G (64 bits)	* ���B���{�ɭ��k���G�Ω�P�_�O�_�������ƭ��k�ץ� 
reg[`DoubleRegBus] hilo_temp1; // �Ω�O�s���֥[/��̲׿�X
reg[`DoubleRegBus] mulres; // �@�뭼�k���O�����k���G (64 bits) / ���֥[��Ĥ@���q���k���G

reg stallreq_for_madd_msub; // �Ω�i�� stallreq �Ӧۦ�ث��O
reg stallreq_for_div;



// �� Regfile �ާ@�H�� (�O�_�g�^�Ȧs��/�g�^���Ȧs���a�}/�g�^�����)
always @ (*) begin
	wd_o <= wd_i; // �ؼмȦs����}
	wreg_o <= wreg_i; // �O�_�g�J�ت��Ȧs��
	
	// ��ƹB�⵲�G����ɤ��g�J�Ȧs��!
	if(((aluop_i == `EXE_ADD_OP) || (aluop_i == `EXE_ADDI_OP) || (aluop_i == `EXE_SUB_OP)) && (ov_sum == 1'b1)) begin
	 	wreg_o <= `WriteDisable;
	end
	else begin
		wreg_o <= wreg_i;
	end
	
	case ( alusel_i ) // ��X
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

// �� HILO �ާ@�H��
always @ (*) begin
	if (rst == `RstEnable) begin
		whilo_o <= `WriteDisable;
		hi_o <= `ZeroWord;
		lo_o <= `ZeroWord;
	end
	else begin
		case (aluop_i)
		// ���k�B��
			`EXE_DIV_OP,`EXE_DIVU_OP: begin
				whilo_o <= `WriteEnable;
				hi_o <= div_result_i[63:32];
				lo_o <= div_result_i[31:0];
			end
		// MTHI MTLO �����ʹB��
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
		
		// MULT MUL �����k�B��
			`EXE_MULT_OP,`EXE_MULTU_OP: begin
				whilo_o <= `WriteEnable;
				hi_o <= mulres[63:32];
				lo_o <= mulres[31:0];
			end
		// MADD MADDU MSUB MSUBU �����k�B��
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

// 1. �ѨM���ʫ��O���ƾڦM�ٰ��D
// 2. �O�s HILO �̷s�� �� HI LO �Ȧs��
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

// �޽u�Ȱ��ӷ�
always @ (*) begin
	stallreq = stallreq_for_madd_msub || stallreq_for_div;
end

/// ���k�B��
always @ (*) begin
	if (rst == `RstEnable) begin
		stallreq_for_div <= `NoStop;
		div_opdata1_o <= `ZeroWord;
		div_opdata2_o <= `ZeroWord;
		div_start_o <= `DivStop;
		signed_div_o <= 1'b0;
	end
	else begin
	// ��l��
		stallreq_for_div <= `NoStop;
		div_opdata1_o <= `ZeroWord;
		div_opdata2_o <= `ZeroWord;
		div_start_o <= `DivStop;
		signed_div_o <= 1'b0;
		
		case(aluop_i)
			`EXE_DIV_OP: begin
				if (div_ready_i == `DivResultNotReady) begin
				// �b���k���G�o��e����޽u�Ȱ�
					stallreq_for_div <= `Stop;
					
					// ���M�b�C�өP�����|��J�ۦP���B��ӷ��A�����k�Ҳդ��u��Ĥ@����J���ӷ��B�� 32 �Ӷg�����X�A�ä��|���s�p��!
					div_opdata1_o <= reg1_i;
					div_opdata2_o <= reg2_i;
					div_start_o <= `DivStart;
					signed_div_o <= 1'b1;
				end
				else if (div_ready_i == `DivResultReady) begin
					stallreq_for_div <= `NoStop;
				
					div_opdata1_o <= reg1_i;
					div_opdata2_o <= reg2_i;
					div_start_o <= `DivStop;	// ����k�p��
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
				// �b���k���G�o��e����޽u�Ȱ�
					stallreq_for_div <= `Stop;
					
					// ���M�b�C�өP�����|��J�ۦP���B��ӷ��A�����k�Ҳդ��u��Ĥ@����J���ӷ��B�� 32 �Ӷg�����X�A�ä��|���s�p��!
					div_opdata1_o <= reg1_i;
					div_opdata2_o <= reg2_i;
					div_start_o <= `DivStart;
					signed_div_o <= 1'b0;
				end
				else if (div_ready_i == `DivResultReady) begin
					stallreq_for_div <= `NoStop;
				
					div_opdata1_o <= reg1_i;
					div_opdata2_o <= reg2_i;
					div_start_o <= `DivStop;	// ����k�p��
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
 ��N�B�� (�@) - �[/��/���/�p��
	1. �Y�� ��k �� �����Ƥ�� �B�� => �ĤG�ӹB�⤸�����ɼ� (reg2_i_mux = ~reg2_i+1)�A�_�h������! (reg2_i_mux = reg2_i)
		�N reg1_i + reg2_i_mux  �|���U�C�T�ر��p
		(a) �[�k (reg2_i_mux = reg2_i)	(b) �[�ɼ� (��k) (reg2_i_mux = ~reg2_i+1)	(c) �[�ɼ� (��k) (�Ω�P�_) (reg2_i_mux = ~reg2_i+1)
	2. ����P�_ (�ȵo�ͦb ADD ADDI SUB) Hint: ��k�S���ߧY���O
		(a) �� + �� = �t	(b) �t + �t = ��
	3. ���
		(a) �L���Ƥ��
			(a.1) ���������B�⤸�j�p (�B�⤸ 1 < �B�⤸ 2)
		(b) �����Ƥ�� (�B�⤸ 1 < �B�⤸ 2 ���T�ر��p)
			(b.1) �B�⤸ 1 ���t 2 ����
			(b.2) �B�⤸ 1 ���� 2 �����A�B result_sum < 0
			(b.3) �B�⤸ 1 ���t 2 ���t�A�B result_sum < 0
	4. �p�� 0 or 1
		(a) �p 0
			a = 000000001010101010...
			a[31]? 0:a[30]? 1:...
		(b) �p 1
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
 ��ƹB�� (�G) -  ���k/���֥[ & ���ִ� �B��
	1. �����ƭ��k:
		�Y���ƩγQ���Ƭ��t�A�N��@�G�ɼơC�Y�����ۭ��h���n�A���G�ɼ�!		*Booth: Booth ���k���G�Y��������!
*/
assign opdata1_mult = ((aluop_i == `EXE_MUL_OP) || (aluop_i == `EXE_MULT_OP) || (aluop_i == `EXE_MADD_OP) || (aluop_i == `EXE_MSUB_OP)) && (reg1_i[31] == 1'b1) ? (~reg1_i + 1) : reg1_i;
assign opdata2_mult = ((aluop_i == `EXE_MUL_OP) || (aluop_i == `EXE_MULT_OP) || (aluop_i == `EXE_MADD_OP) || (aluop_i == `EXE_MSUB_OP)) && (reg2_i[31] == 1'b1) ? (~reg2_i + 1) : reg2_i;
assign hilo_temp = opdata1_mult * opdata2_mult;

// �{�ɭ��k���G���ץ� (�Y�����ۭ��h���Z�A���G�ɼ�)
always @ (*) begin
	if (rst == `RstEnable) begin
		mulres <= {`ZeroWord,`ZeroWord};
	end
	else if ((aluop_i == `EXE_MUL_OP) || (aluop_i == `EXE_MULT_OP) || (aluop_i == `EXE_MADD_OP) || (aluop_i == `EXE_MSUB_OP)) begin	// �����ƭ��k
		if (reg1_i[31] ^ reg2_i[31] == 1'b1) begin // �ץ�
			mulres <= (~hilo_temp + 1);
		end
		else begin
			mulres <= hilo_temp;
		end
	end
	else begin // �L���ƭ��k
		mulres <= hilo_temp;
	end
end

// ���֥[ & ���ִ� �B��
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
					hilo_temp_o <= mulres;	// �N�Ĥ@���q���G��X�� ex/mem ���q���Ȧs��
					cnt_o <= 2'b01;	// �O����U�B��Ĥ@���q�B��
					hilo_temp1 <= {`ZeroWord,`ZeroWord};	// �̲׿�X�Ȧs���b�Ĥ@���q�B����٬O0
					stallreq_for_madd_msub <= `Stop;	// �޽u�Ȱ��ШD
				end
				else if (cnt_i == 2'b01) begin
					hilo_temp_o <= {`ZeroWord,`ZeroWord}; // �N��X���G�M�s
					cnt_o <= 2'b10;
					hilo_temp1 <= hilo_temp_i + {HI,LO};
					stallreq_for_madd_msub <= `NoStop;
				end
			end
			`EXE_MSUB_OP,`EXE_MSUBU_OP: begin
				if (cnt_i == 2'b00) begin
					hilo_temp_o <= ~mulres + 1; // ���ִ� (�Ĥ@���q���G���ɼ�)
					cnt_o <= 2'b01;
					hilo_temp1 <= {`ZeroWord,`ZeroWord};
					stallreq_for_madd_msub <= `Stop;
				end
				else if (cnt_i == 2'b01) begin
					hilo_temp_o <= {`ZeroWord,`ZeroWord}; // �N��X���G�M�s
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


// ���ʹB��
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


// �޿�B��
always @ (*) begin
	if(rst == `RstEnable) begin
		logicout <= `ZeroWord;
	end else begin
		case (aluop_i) // �B��B�O�s
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

// �첾�B��
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