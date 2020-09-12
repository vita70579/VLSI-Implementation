`include "defines.v"

module openmips( // �s���U IP
	input wire clk,
	input wire rst,
	
	input wire[`RegBus] rom_data_i, // ���O�O������o�����O
	output wire[`RegBus] rom_addr_o, // ��X����O�O���骺��}
	output wire rom_ce_o // ���O�O���� enable
	
);

// �s�� IF/ID �P ID �� wire
wire[`InstAddrBus] id_pc_i;
wire[`InstBus] id_inst_i;

// �s�� ID �P ID/EX �� wire
wire[`AluOpBus] id_aluop_o;
wire[`AluSelBus] id_alusel_o;
wire[`RegBus] id_reg1_o;
wire[`RegBus] id_reg2_o;
wire id_wreg_o;
wire[`RegAddrBus] id_wd_o;
wire id_is_in_delayslot_o;
wire[`RegBus] id_link_address_o;

// �s�� ID/EX �P EX �� wire
wire[`AluOpBus] ex_aluop_i;
wire[`AluSelBus] ex_alusel_i;
wire[`RegBus] ex_reg1_i;
wire[`RegBus] ex_reg2_i;
wire ex_wreg_i;
wire[`RegAddrBus] ex_wd_i;
wire ex_is_in_delayslot_i;	
wire[`RegBus] ex_link_address_i;

// �s�� EX �P EX/MEM �� wire
wire ex_wreg_o;
wire[`RegAddrBus] ex_wd_o;
wire[`RegBus] ex_wdata_o;
wire ex_whilo_o;	// EX ��X�ݨ� EX/MEM ��J��
wire[`RegBus] ex_hi_o;
wire[`RegBus] ex_lo_o;

// �s�� EX/MEM �P MEM �� wire
wire mem_wreg_i;
wire[`RegAddrBus] mem_wd_i;
wire[`RegBus] mem_wdata_i;
wire[`RegBus] mem_hi_i;	// EX/MEM ��X�ݨ� MEM ��J��
wire[`RegBus] mem_lo_i;
wire mem_whilo_i;

// �s�� MEM �P MEM/WB �� wire
wire mem_wreg_o;
wire[`RegAddrBus] mem_wd_o;
wire[`RegBus] mem_wdata_o;
wire mem_whilo_o; // MEM ��X�ݨ� MEM/WB ��J��
wire[`RegBus] mem_hi_o;
wire[`RegBus] mem_lo_o;

// �s�� MEM/WB �P WB �� wire	
wire wb_wreg_i;
wire[`RegAddrBus] wb_wd_i;
wire[`RegBus] wb_wdata_i;
wire[`RegBus] wb_hi_i;	// MEM/WB ��X�ݨ� WB ��J��
wire[`RegBus] wb_lo_i;
wire wb_whilo_i;

/*
    ����ѫ��O�B�z
*/
wire is_in_delayslot_i; // ID/EXE -> ID
wire is_in_delayslot_o;
wire next_inst_in_delayslot_o; // ID -> ID/EXE
wire id_branch_flag_o; // ID -> PC
wire[`RegBus] branch_target_address; // ID -> PC
///=============================================================================///

// �s���� pc_reg �� wire
wire[`InstAddrBus] pc;


// �s�� ID �P Regfile �� wire
wire reg1_read;
wire reg2_read;
wire[`RegBus] reg1_data;
wire[`RegBus] reg2_data;
wire[`RegAddrBus] reg1_addr;
wire[`RegAddrBus] reg2_addr;

// �s�� HILO �� EXE �� wire
wire[`RegBus] hi;
wire[`RegBus] lo;

//�s��EXE - EXE/MEM�A�Ω�h�g���� MADD MADDU MSUB MSUBU ���O
wire[`DoubleRegBus] hilo_temp_o;
wire[1:0] cnt_o;

wire[`DoubleRegBus] hilo_temp_i;
wire[1:0] cnt_i;

wire[5:0] stall;
wire stallreq_from_id;	
wire stallreq_from_ex;

// �s�� EXE �� DIV �� wire
wire div_start;
wire div_ready;
wire [`RegBus] div_opdata_1;
wire [`RegBus] div_opdata_2;
wire signed_div;
wire [`DoubleRegBus]div_result;

// ctrl ��Ҥ�
ctrl ctrl0(
	// in
	.rst(rst),
	.stallreq_from_id(stallreq_from_id),
	.stallreq_from_ex(stallreq_from_ex),
	
	// out
	.stall(stall)
);

// pc_reg ��Ҥ�
pc_reg pc_reg0(
	// in
	.clk(clk),
	.rst(rst),
	.stall(stall), // �޽u�Ȱ�
	
	/*
	����ѳB�z
	*/
	.branch_flag_i(id_branch_flag_o),
	.branch_target_address_i(branch_target_address),
	
	// out
	.pc(pc),
	.ce(rom_ce_o)
);

//�q�αH�s��Regfile�Ҥ�
regfile regfile1(
	// in
	.clk (clk),
	.rst (rst),
	
	.we	(wb_wreg_i),
	.waddr (wb_wd_i),
	.wdata (wb_wdata_i),
	
	// out
	.re1 (reg1_read),
	.raddr1 (reg1_addr),
	.rdata1 (reg1_data),
	.re2 (reg2_read),
	.raddr2 (reg2_addr),
	.rdata2 (reg2_data)
);

// HILO �Ҳչ�Ҥ�
hilo_reg hilo_reg0(
	// in
	.clk(clk),
	.rst(rst),

	// out
	// �g�ݤf
	.we(wb_whilo_i),
	.hi_i(wb_hi_i),
	.lo_i(wb_lo_i),

	// in
	// Ū�ݤf1
	.hi_o(hi),
	.lo_o(lo)	
);
	
 assign rom_addr_o = pc; // pc ���ȴN�O�n��X����O�O���骺��}
 
// ���k�Ҳչ�Ҥ�
div div0(
	.clk(clk), 
	.rst(rst), 
	.signed_div_i(signed_div), 
	.opdata1_i(div_opdata_1), 
	.opdata2_i(div_opdata_2),
	.start_i(div_start), 
	.annul_i(1'b0), 
	.result_o(div_result), 
	.ready_o(div_ready)
);

//IF/ID�ҹ�Ҥ�
if_id if_id0(
	// in
	.clk(clk),
	.rst(rst),
	.stall(stall),
	
	.if_pc(pc),
	.if_inst(rom_data_i),
	
	.id_pc(id_pc_i),	// out
	.id_inst(id_inst_i)	// out	
);

//ID�Ҳչ�Ҥ�
id id0(
	// in
	.rst(rst),
	// out
	.stallreq(stallreq_from_id),
	
	.pc_i(id_pc_i),
	.inst_i(id_inst_i),
	
	.reg1_data_i(reg1_data),
	.reg2_data_i(reg2_data),

	// out
	//�e��regfile���H��
	.reg1_read_o(reg1_read),
	.reg2_read_o(reg2_read),

	.reg1_addr_o(reg1_addr),
	.reg2_addr_o(reg2_addr),
  
	//�e��ID/EX�Ҳժ��H��
	.aluop_o(id_aluop_o),
	.alusel_o(id_alusel_o),
	.reg1_o(id_reg1_o),
	.reg2_o(id_reg2_o),
	.wd_o(id_wd_o),
	.wreg_o(id_wreg_o),
	
	/// �e�X
	// EXE ���q�����G
	
	// in
	.ex_wreg_i(ex_wreg_o),
	.ex_wdata_i(ex_wdata_o),
	.ex_wd_i(ex_wd_o),
	
	// MEM ���q�����G
	
	// in
	.mem_wreg_i(mem_wreg_o),
	.mem_wdata_i(mem_wdata_o),
	.mem_wd_i(mem_wd_o),
	
	/*
	����ѫ��O�B�z
	*/
	// in
	.is_in_delayslot_i(is_in_delayslot_i),
	
	// out
	.next_inst_in_delayslot_o(next_inst_in_delayslot_o),	
    .branch_flag_o(id_branch_flag_o),
    .branch_target_address_o(branch_target_address),       
    .link_addr_o(id_link_address_o),
    .is_in_delayslot_o(id_is_in_delayslot_o)
);


//ID/EX�Ҳ�
id_ex id_ex0(
	// in
	.clk(clk),
	.rst(rst),
	.stall(stall),
	
	// �� ID �ǰe�T��
	.id_aluop(id_aluop_o),
	.id_alusel(id_alusel_o),
	.id_reg1(id_reg1_o),
	.id_reg2(id_reg2_o),
	.id_wd(id_wd_o),
	.id_wreg(id_wreg_o),

	// out
	
	// �ǰe�� EX �T��
	.ex_aluop(ex_aluop_i),
	.ex_alusel(ex_alusel_i),
	.ex_reg1(ex_reg1_i),
	.ex_reg2(ex_reg2_i),
	.ex_wd(ex_wd_i),
	.ex_wreg(ex_wreg_i),
	
	/*
	����ѫ��O�B�z
	*/
	// in
	.id_link_address(id_link_address_o),
	.id_is_in_delayslot(id_is_in_delayslot_o),
	.next_inst_in_delayslot_i(next_inst_in_delayslot_o),
	
	// out
	.ex_link_address(ex_link_address_i),
  	.ex_is_in_delayslot(ex_is_in_delayslot_i),
	.is_in_delayslot_o(is_in_delayslot_i)
);		

//EX�Ҳ�
ex ex0(
	// in
	.rst(rst),
	// out
	.stallreq(stallreq_from_ex),

	// �e�� EXE ���q�T��
	.aluop_i(ex_aluop_i),
	.alusel_i(ex_alusel_i),
	.reg1_i(ex_reg1_i),
	.reg2_i(ex_reg2_i),
	.wd_i(ex_wd_i),
	.wreg_i(ex_wreg_i),
	
	.hi_i(hi),
	.lo_i(lo),
	
	.wb_hi_i(wb_hi_i),
	.wb_lo_i(wb_lo_i),
	.wb_whilo_i(wb_whilo_i),
	.mem_hi_i(mem_hi_o),
	.mem_lo_i(mem_lo_o),
	.mem_whilo_i(mem_whilo_o),
  
	// out
	
	// EX ��X�� EX/MEM �T��
	.wd_o(ex_wd_o),
	.wreg_o(ex_wreg_o),
	.wdata_o(ex_wdata_o),
	
	.hi_o(ex_hi_o),
	.lo_o(ex_lo_o),
	.whilo_o(ex_whilo_o),
	
	// ��X�ΫO�s�� ex/mem ���H�� (�h���O�P�������֥[/��)
	// out
	.hilo_temp_o(hilo_temp_o),
	.cnt_o(cnt_o),
	// in
	.hilo_temp_i(hilo_temp_i),
	.cnt_i(cnt_i),
	
	// �s�����k�Ҳ�
	// out
	.div_start_o(div_start),
	.div_opdata1_o(div_opdata_1),
	.div_opdata2_o(div_opdata_2),
	.signed_div_o(signed_div),
	
	// in
	.div_result_i(div_result),
	.div_ready_i(div_ready),
	
	/*
	����ѫ��O�B�z
	*/
    // in
	.link_address_i(ex_link_address_i),
	.is_in_delayslot_i(ex_is_in_delayslot_i)
);

//EX/MEM�Ҳ�
ex_mem ex_mem0(
	// in
	.clk(clk),
	.rst(rst),
	.stall(stall),
  
	// �Ӧ� EX �T��
	.ex_wd(ex_wd_o),
	.ex_wreg(ex_wreg_o),
	.ex_wdata(ex_wdata_o),
	
	.ex_hi(ex_hi_o),
	.ex_lo(ex_lo_o),
	.ex_whilo(ex_whilo_o),

	// out
	
	// �Ǧ� MEM �T��
	.mem_wd(mem_wd_i),
	.mem_wreg(mem_wreg_i),
	.mem_wdata(mem_wdata_i),
	
	.mem_hi(mem_hi_i),
	.mem_lo(mem_lo_i),
	.mem_whilo(mem_whilo_i),
	
	// �^�ǩΫO�s�� ex ���H�� (�h���O�P�������֥[/��)
	// in
	.hilo_i(hilo_temp_o),
	.cnt_i(cnt_o),
	// out
	.hilo_o(hilo_temp_i),
	.cnt_o(cnt_i)
);

//MEM�ҲըҤ�
mem mem0(
	// in
	.rst(rst),

	//�Ӧ� EX/MEM �T��	
	.wd_i(mem_wd_i),
	.wreg_i(mem_wreg_i),
	.wdata_i(mem_wdata_i),
	
	.hi_i(mem_hi_i),
	.lo_i(mem_lo_i),
	.whilo_i(mem_whilo_i),
  
	// out
	
	//�e�� MEM/WB �T��
	.wd_o(mem_wd_o),
	.wreg_o(mem_wreg_o),
	.wdata_o(mem_wdata_o),
	
	.hi_o(mem_hi_o),
	.lo_o(mem_lo_o),
	.whilo_o(mem_whilo_o)
);

//MEM/WB�Ҳ�
mem_wb mem_wb0(
	// in
	.clk(clk),
	.rst(rst),
	.stall(stall),

	// �Ӧ� MEM �T��
	.mem_wd(mem_wd_o),
	.mem_wreg(mem_wreg_o),
	.mem_wdata(mem_wdata_o),
	
	.mem_hi(mem_hi_o),
	.mem_lo(mem_lo_o),
	.mem_whilo(mem_whilo_o),
	
	// out
	// �Ǧ� WB �T��
	.wb_wd(wb_wd_i),
	.wb_wreg(wb_wreg_i),
	.wb_wdata(wb_wdata_i),
	
	.wb_hi(wb_hi_i),
	.wb_lo(wb_lo_i),
	.wb_whilo(wb_whilo_i)
	
);
endmodule