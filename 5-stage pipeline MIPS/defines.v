// 定義
`define RstEnable 1'b1
`define RstDisable 1'b0
`define ZeroWord 32'h00000000
`define WriteEnable 1'b1
`define WriteDisable 1'b0
`define ReadEnable 1'b1
`define ReadDisable 1'b0
`define AluOpBus 7:0
`define AluSelBus 2:0
`define InstValid 1'b0
`define InstInvalid 1'b1
`define Stop 1'b1
`define NoStop 1'b0
`define Branch 1'b1	// 轉移
`define NotBranch 1'b0	// 不轉移
`define InterruptAssert 1'b1
`define InterruptNotAssert 1'b0
`define TrapAssert 1'b1
`define TrapNotAssert 1'b0
`define True_v 1'b1
`define False_v 1'b0
`define ChipEnable 1'b1
`define ChipDisable 1'b0
`define InDelaySlot 1'b1 // 在延遲槽中
`define NotInDelaySlot 1'b0 // 不在延遲槽中


//指令 (funct code)
`define EXE_AND  6'b100100 // and 
`define EXE_OR   6'b100101 // or
`define EXE_XOR 6'b100110 // xor
`define EXE_NOR 6'b100111 // nor
`define EXE_ANDI 6'b001100 // andi
`define EXE_ORI  6'b001101 // ori
`define EXE_XORI 6'b001110 // xori
`define EXE_LUI 6'b001111 // lui

`define EXE_SLL  6'b000000 // sll
`define EXE_SLLV  6'b000100 // sllv
`define EXE_SRL  6'b000010 // srl
`define EXE_SRLV  6'b000110 // srlv
`define EXE_SRA  6'b000011 // sra
`define EXE_SRAV  6'b000111 // srav
`define EXE_SYNC  6'b001111 // sync
`define EXE_PREF  6'b110011 // pref

`define EXE_MOVZ  6'b001010 // movz $rd,$rs,$rt # if $rt=0 then $rd <= $rs
`define EXE_MOVN  6'b001011 // movn $rd,$rs,$rt # if $rt =\0 then $rd <= $rs
`define EXE_MFHI  6'b010000 // $rd <= $HI
`define EXE_MTHI  6'b010001 // $HI <= $rs
`define EXE_MFLO  6'b010010 // $rd <= $LO
`define EXE_MTLO  6'b010011 // $LO <= $rs

`define EXE_SLT  6'b101010	// $rd <= ($rs < $ rt) (有號數比較)
`define EXE_SLTU  6'b101011	// $rd <= ($rs < $ rt) (無號數比較)
`define EXE_SLTI  6'b001010	// $rt <= ($rs < (sign_extended)imm) (有號數比較)
`define EXE_SLTIU  6'b001011	// $rt <= ($rs < (sign_extended)imm) (無號數比較)
`define EXE_ADD  6'b100000	// $rd <= $rs + $rt (overflow 不保存結果)
`define EXE_ADDU  6'b100001	// $rd <= $rs + $rt (overflow 保存結果)
`define EXE_SUB  6'b100010	// $rd <= $rs - $rt (overflow 不保存結果)
`define EXE_SUBU  6'b100011	// $rd <= $rs - $rt (overflow 保存結果)
`define EXE_ADDI  6'b001000	// $rt <= $rs + (sign_extended)imm (overflow 不保存結果)
`define EXE_ADDIU  6'b001001	// $rt <= $rs + (sign_extended)imm (overflow 保存結果)
`define EXE_CLZ  6'b100000	// $rd <= count_leading_zero ($rs)
`define EXE_CLO  6'b100001	// $rd <= count_leading_one ($rs)

`define EXE_MULT  6'b011000 // {HI,LO} <= $rs * $rt (有號)
`define EXE_MULTU  6'b011001	// {HI,LO} <= $rs * $rt (無號)
`define EXE_MUL  6'b000010	// $rd <= $rs * $rt (有號)(取低32 bits)

`define EXE_MADD  6'b000000 // {HI,LO} <= {HI,LO} + $rs * $rt (有號累加)
`define EXE_MADDU  6'b000001 // {HI,LO} <= {HI,LO} + $rs * $rt (無號累加)
`define EXE_MSUB  6'b000100 // {HI,LO} <= {HI,LO} - $rs * $rt (有號累減)
`define EXE_MSUBU  6'b000101 // {HI,LO} <= {HI,LO} - $rs * $rt (無號累減)

`define EXE_DIV 6'b011010 // {HI,LO} <= rs/rt (有號)
`define EXE_DIVU 6'b011011	// {HI,LO} <= rs/rt (無號)

`define EXE_J  6'b000010 // pc <= (pc+4)[31:28],{target,00}
`define EXE_JAL  6'b000011 // pc同上, 額外將跳轉指令後第二條指令做違反為地址保存到 $31
`define EXE_JALR  6'b001001 // rd <= 跳轉指令後第二條指令作為返回地址(若沒在指令中指明rd，默認保存到$31);  pc <= $rs
`define EXE_JR  6'b001000 // pc <= $rs
/*
    所有分支指令的轉移目標地址為: (signed_extend){offset,00} + (pc+4)
*/
`define EXE_BEQ  6'b000100 //  if $rs == $rt then branch
`define EXE_BGEZ  5'b00001 // if rs>=0 then branch
`define EXE_BGEZAL  5'b10001 // if rs>=0 then branch;   將跳轉指令後第二條指令做違反為地址保存到 $31
`define EXE_BGTZ  6'b000111 // if $rs>0 then branch
`define EXE_BLEZ  6'b000110 // if $rs<=0 then branch
`define EXE_BLTZ  5'b00000 // if $rs<0 then branch
`define EXE_BLTZAL  5'b10000 // if $rs<0 then branch;   將跳轉指令後第二條指令做違反為地址保存到 $31
`define EXE_BNE  6'b000101 // if $rs =/ $rt then branch

`define EXE_NOP 6'b000000
`define SSNOP 32'b00000000000000000000000001000000

`define EXE_SPECIAL_INST 6'b000000
`define EXE_REGIMM_INST 6'b000001
`define EXE_SPECIAL2_INST 6'b011100


//AluOp (OP code)
`define EXE_AND_OP   8'b00100100
`define EXE_OR_OP    8'b00100101
`define EXE_XOR_OP  8'b00100110
`define EXE_NOR_OP  8'b00100111
`define EXE_ANDI_OP  8'b01011001
`define EXE_ORI_OP  8'b01011010
`define EXE_XORI_OP  8'b01011011
`define EXE_LUI_OP  8'b01011100   

`define EXE_SLL_OP  8'b01111100
`define EXE_SLLV_OP  8'b00000100
`define EXE_SRL_OP  8'b00000010
`define EXE_SRLV_OP  8'b00000110
`define EXE_SRA_OP  8'b00000011
`define EXE_SRAV_OP  8'b00000111

`define EXE_MOVZ_OP  8'b00001010
`define EXE_MOVN_OP  8'b00001011
`define EXE_MFHI_OP  8'b00010000
`define EXE_MTHI_OP  8'b00010001
`define EXE_MFLO_OP  8'b00010010
`define EXE_MTLO_OP  8'b00010011

`define EXE_SLT_OP  8'b00101010
`define EXE_SLTU_OP  8'b00101011
`define EXE_SLTI_OP  8'b01010111
`define EXE_SLTIU_OP  8'b01011000   
`define EXE_ADD_OP  8'b00100000
`define EXE_ADDU_OP  8'b00100001
`define EXE_SUB_OP  8'b00100010
`define EXE_SUBU_OP  8'b00100011
`define EXE_ADDI_OP  8'b01010101
`define EXE_ADDIU_OP  8'b01010110
`define EXE_CLZ_OP  8'b10110000
`define EXE_CLO_OP  8'b10110001

`define EXE_MULT_OP  8'b00011000
`define EXE_MULTU_OP  8'b00011001
`define EXE_MUL_OP  8'b10101001

`define EXE_MADD_OP  8'b10100110
`define EXE_MADDU_OP  8'b10101000
`define EXE_MSUB_OP  8'b10101010
`define EXE_MSUBU_OP  8'b10101011

`define EXE_DIV_OP	8'b00011010
`define EXE_DIVU_OP	8'b00011011

`define EXE_J_OP  8'b01001111	// pc <= ( pc + 4 )[31:28] | target << 2
`define EXE_JAL_OP  8'b01010000	// pc <= (pc + 4) [31:28] | target <<2 // $31 <= pc + 4 + 4
`define EXE_JALR_OP  8'b00001001	// pc <= $rs // $rd <= pc + 4 + 4
`define EXE_JR_OP  8'b00001000	// pc <= $rs

`define EXE_BEQ_OP  8'b01010001	// if rs = rt then branch ... new addr = (signed_extend)(off set <<2) + (pc + 4)
`define EXE_BGEZ_OP  8'b01000001	// if rs >= 0 then branch ... new addr = (signed_extend)(off set <<2) + (pc + 4)
`define EXE_BGEZAL_OP  8'b01001011	// if rs >= 0 then branch ... new addr = (signed_extend)(off set <<2) + (pc + 4) // $31 <= pc + 4 + 4
`define EXE_BGTZ_OP  8'b01010100	// if rs > 0 then branch ... new addr = (signed_extend)(off set <<2) + (pc + 4)
`define EXE_BLEZ_OP  8'b01010011	// if rs < rt then branch ... new addr = (signed_extend)(off set <<2) + (pc + 4)
`define EXE_BLTZ_OP  8'b01000000	// if rs < 0 then branch ... new addr = (signed_extend)(off set <<2) + (pc + 4)
`define EXE_BLTZAL_OP  8'b01001010	// if rs < 0 then branch ... new addr = (signed_extend)(off set <<2) + (pc + 4) // $31 <= pc + 4 + 4
`define EXE_BNE_OP  8'b01010010	// if rs =/ rt then branch ... new addr = (signed_extend)(off set <<2) + (pc + 4)

`define EXE_NOP_OP	8'b00000000

//AluSel (在執行階段要執行的運算類型)
`define EXE_RES_LOGIC 3'b001
`define EXE_RES_SHIFT 3'b010
`define EXE_RES_MOVE 3'b011
	/// MTHI MTLO / MADD MADDU MSUB MSUBU 沒有要寫回 Regfile 所以沒有對應的 AluSel
`define EXE_RES_ARITHMETIC 3'b100	
`define EXE_RES_MUL 3'b101
`define EXE_RES_JUMP_BRANCH 3'b110
`define EXE_RES_NOP 3'b000


//指令儲存器 inst_rom
`define InstAddrBus 31:0
`define InstBus 31:0
`define InstMemNum 131071
`define InstMemNumLog2 17

// 除法模組
`define DivFree 2'b00
`define DivByZero 2'b01
`define DivOn 2'b10
`define DivEnd 2'b11
`define DivResultReady 1'b1
`define DivResultNotReady 1'b0
`define DivStart 1'b1
`define DivStop 1'b0


//通用寄存器regfile
`define RegAddrBus 4:0
`define RegBus 31:0
`define RegWidth 32
`define DoubleRegWidth 64
`define DoubleRegBus 63:0
`define RegNum 32
`define RegNumLog2 5 //choose one reg of total 32
`define NOPRegAddr 5'b00000