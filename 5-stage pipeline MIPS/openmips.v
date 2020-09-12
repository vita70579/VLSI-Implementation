`include "defines.v"

module openmips( // 連接各 IP
	input wire clk,
	input wire rst,
	
	input wire[`RegBus] rom_data_i, // 指令記憶體取得的指令
	output wire[`RegBus] rom_addr_o, // 輸出到指令記憶體的位址
	output wire rom_ce_o // 指令記憶體 enable
	
);

// 連接 IF/ID 與 ID 的 wire
wire[`InstAddrBus] id_pc_i;
wire[`InstBus] id_inst_i;

// 連接 ID 與 ID/EX 的 wire
wire[`AluOpBus] id_aluop_o;
wire[`AluSelBus] id_alusel_o;
wire[`RegBus] id_reg1_o;
wire[`RegBus] id_reg2_o;
wire id_wreg_o;
wire[`RegAddrBus] id_wd_o;
wire id_is_in_delayslot_o;
wire[`RegBus] id_link_address_o;

// 連接 ID/EX 與 EX 的 wire
wire[`AluOpBus] ex_aluop_i;
wire[`AluSelBus] ex_alusel_i;
wire[`RegBus] ex_reg1_i;
wire[`RegBus] ex_reg2_i;
wire ex_wreg_i;
wire[`RegAddrBus] ex_wd_i;
wire ex_is_in_delayslot_i;	
wire[`RegBus] ex_link_address_i;

// 連接 EX 與 EX/MEM 的 wire
wire ex_wreg_o;
wire[`RegAddrBus] ex_wd_o;
wire[`RegBus] ex_wdata_o;
wire ex_whilo_o;	// EX 輸出端到 EX/MEM 輸入端
wire[`RegBus] ex_hi_o;
wire[`RegBus] ex_lo_o;

// 連接 EX/MEM 與 MEM 的 wire
wire mem_wreg_i;
wire[`RegAddrBus] mem_wd_i;
wire[`RegBus] mem_wdata_i;
wire[`RegBus] mem_hi_i;	// EX/MEM 輸出端到 MEM 輸入端
wire[`RegBus] mem_lo_i;
wire mem_whilo_i;

// 連接 MEM 與 MEM/WB 的 wire
wire mem_wreg_o;
wire[`RegAddrBus] mem_wd_o;
wire[`RegBus] mem_wdata_o;
wire mem_whilo_o; // MEM 輸出端到 MEM/WB 輸入端
wire[`RegBus] mem_hi_o;
wire[`RegBus] mem_lo_o;

// 連接 MEM/WB 與 WB 的 wire	
wire wb_wreg_i;
wire[`RegAddrBus] wb_wd_i;
wire[`RegBus] wb_wdata_i;
wire[`RegBus] wb_hi_i;	// MEM/WB 輸出端到 WB 輸入端
wire[`RegBus] wb_lo_i;
wire wb_whilo_i;

/*
    延遲槽指令處理
*/
wire is_in_delayslot_i; // ID/EXE -> ID
wire is_in_delayslot_o;
wire next_inst_in_delayslot_o; // ID -> ID/EXE
wire id_branch_flag_o; // ID -> PC
wire[`RegBus] branch_target_address; // ID -> PC
///=============================================================================///

// 連接到 pc_reg 的 wire
wire[`InstAddrBus] pc;


// 連接 ID 與 Regfile 的 wire
wire reg1_read;
wire reg2_read;
wire[`RegBus] reg1_data;
wire[`RegBus] reg2_data;
wire[`RegAddrBus] reg1_addr;
wire[`RegAddrBus] reg2_addr;

// 連接 HILO 到 EXE 的 wire
wire[`RegBus] hi;
wire[`RegBus] lo;

//連接EXE - EXE/MEM，用於多週期的 MADD MADDU MSUB MSUBU 指令
wire[`DoubleRegBus] hilo_temp_o;
wire[1:0] cnt_o;

wire[`DoubleRegBus] hilo_temp_i;
wire[1:0] cnt_i;

wire[5:0] stall;
wire stallreq_from_id;	
wire stallreq_from_ex;

// 連接 EXE 到 DIV 的 wire
wire div_start;
wire div_ready;
wire [`RegBus] div_opdata_1;
wire [`RegBus] div_opdata_2;
wire signed_div;
wire [`DoubleRegBus]div_result;

// ctrl 實例化
ctrl ctrl0(
	// in
	.rst(rst),
	.stallreq_from_id(stallreq_from_id),
	.stallreq_from_ex(stallreq_from_ex),
	
	// out
	.stall(stall)
);

// pc_reg 實例化
pc_reg pc_reg0(
	// in
	.clk(clk),
	.rst(rst),
	.stall(stall), // 管線暫停
	
	/*
	延遲槽處理
	*/
	.branch_flag_i(id_branch_flag_o),
	.branch_target_address_i(branch_target_address),
	
	// out
	.pc(pc),
	.ce(rom_ce_o)
);

//通用寄存器Regfile例化
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

// HILO 模組實例化
hilo_reg hilo_reg0(
	// in
	.clk(clk),
	.rst(rst),

	// out
	// 寫端口
	.we(wb_whilo_i),
	.hi_i(wb_hi_i),
	.lo_i(wb_lo_i),

	// in
	// 讀端口1
	.hi_o(hi),
	.lo_o(lo)	
);
	
 assign rom_addr_o = pc; // pc 的值就是要輸出到指令記憶體的位址
 
// 除法模組實例化
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

//IF/ID模實例化
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

//ID模組實例化
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
	//送到regfile的信息
	.reg1_read_o(reg1_read),
	.reg2_read_o(reg2_read),

	.reg1_addr_o(reg1_addr),
	.reg2_addr_o(reg2_addr),
  
	//送到ID/EX模組的信息
	.aluop_o(id_aluop_o),
	.alusel_o(id_alusel_o),
	.reg1_o(id_reg1_o),
	.reg2_o(id_reg2_o),
	.wd_o(id_wd_o),
	.wreg_o(id_wreg_o),
	
	/// 前饋
	// EXE 階段的結果
	
	// in
	.ex_wreg_i(ex_wreg_o),
	.ex_wdata_i(ex_wdata_o),
	.ex_wd_i(ex_wd_o),
	
	// MEM 階段的結果
	
	// in
	.mem_wreg_i(mem_wreg_o),
	.mem_wdata_i(mem_wdata_o),
	.mem_wd_i(mem_wd_o),
	
	/*
	延遲槽指令處理
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


//ID/EX模組
id_ex id_ex0(
	// in
	.clk(clk),
	.rst(rst),
	.stall(stall),
	
	// 由 ID 傳送訊息
	.id_aluop(id_aluop_o),
	.id_alusel(id_alusel_o),
	.id_reg1(id_reg1_o),
	.id_reg2(id_reg2_o),
	.id_wd(id_wd_o),
	.id_wreg(id_wreg_o),

	// out
	
	// 傳送到 EX 訊息
	.ex_aluop(ex_aluop_i),
	.ex_alusel(ex_alusel_i),
	.ex_reg1(ex_reg1_i),
	.ex_reg2(ex_reg2_i),
	.ex_wd(ex_wd_i),
	.ex_wreg(ex_wreg_i),
	
	/*
	延遲槽指令處理
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

//EX模組
ex ex0(
	// in
	.rst(rst),
	// out
	.stallreq(stallreq_from_ex),

	// 送到 EXE 階段訊息
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
	
	// EX 輸出到 EX/MEM 訊息
	.wd_o(ex_wd_o),
	.wreg_o(ex_wreg_o),
	.wdata_o(ex_wdata_o),
	
	.hi_o(ex_hi_o),
	.lo_o(ex_lo_o),
	.whilo_o(ex_whilo_o),
	
	// 輸出或保存到 ex/mem 的信息 (多指令周期的乘累加/減)
	// out
	.hilo_temp_o(hilo_temp_o),
	.cnt_o(cnt_o),
	// in
	.hilo_temp_i(hilo_temp_i),
	.cnt_i(cnt_i),
	
	// 連接除法模組
	// out
	.div_start_o(div_start),
	.div_opdata1_o(div_opdata_1),
	.div_opdata2_o(div_opdata_2),
	.signed_div_o(signed_div),
	
	// in
	.div_result_i(div_result),
	.div_ready_i(div_ready),
	
	/*
	延遲槽指令處理
	*/
    // in
	.link_address_i(ex_link_address_i),
	.is_in_delayslot_i(ex_is_in_delayslot_i)
);

//EX/MEM模組
ex_mem ex_mem0(
	// in
	.clk(clk),
	.rst(rst),
	.stall(stall),
  
	// 來自 EX 訊息
	.ex_wd(ex_wd_o),
	.ex_wreg(ex_wreg_o),
	.ex_wdata(ex_wdata_o),
	
	.ex_hi(ex_hi_o),
	.ex_lo(ex_lo_o),
	.ex_whilo(ex_whilo_o),

	// out
	
	// 傳至 MEM 訊息
	.mem_wd(mem_wd_i),
	.mem_wreg(mem_wreg_i),
	.mem_wdata(mem_wdata_i),
	
	.mem_hi(mem_hi_i),
	.mem_lo(mem_lo_i),
	.mem_whilo(mem_whilo_i),
	
	// 回傳或保存到 ex 的信息 (多指令周期的乘累加/減)
	// in
	.hilo_i(hilo_temp_o),
	.cnt_i(cnt_o),
	// out
	.hilo_o(hilo_temp_i),
	.cnt_o(cnt_i)
);

//MEM模組例化
mem mem0(
	// in
	.rst(rst),

	//來自 EX/MEM 訊息	
	.wd_i(mem_wd_i),
	.wreg_i(mem_wreg_i),
	.wdata_i(mem_wdata_i),
	
	.hi_i(mem_hi_i),
	.lo_i(mem_lo_i),
	.whilo_i(mem_whilo_i),
  
	// out
	
	//送到 MEM/WB 訊息
	.wd_o(mem_wd_o),
	.wreg_o(mem_wreg_o),
	.wdata_o(mem_wdata_o),
	
	.hi_o(mem_hi_o),
	.lo_o(mem_lo_o),
	.whilo_o(mem_whilo_o)
);

//MEM/WB模組
mem_wb mem_wb0(
	// in
	.clk(clk),
	.rst(rst),
	.stall(stall),

	// 來自 MEM 訊息
	.mem_wd(mem_wd_o),
	.mem_wreg(mem_wreg_o),
	.mem_wdata(mem_wdata_o),
	
	.mem_hi(mem_hi_o),
	.mem_lo(mem_lo_o),
	.mem_whilo(mem_whilo_o),
	
	// out
	// 傳至 WB 訊息
	.wb_wd(wb_wd_i),
	.wb_wreg(wb_wreg_i),
	.wb_wdata(wb_wdata_i),
	
	.wb_hi(wb_hi_i),
	.wb_lo(wb_lo_i),
	.wb_whilo(wb_whilo_i)
	
);
endmodule