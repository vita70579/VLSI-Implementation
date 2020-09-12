//////////////////////////////////////////////////////////////////////
////                                                              ////
//// Copyright (C) 2014 leishangwen@163.com                       ////
////                                                              ////
//// This source file may be used and distributed without         ////
//// restriction provided that this copyright statement is not    ////
//// removed from the file and that any derivative work contains  ////
//// the original copyright notice and the associated disclaimer. ////
////                                                              ////
//// This source file is free software; you can redistribute it   ////
//// and/or modify it under the terms of the GNU Lesser General   ////
//// Public License as published by the Free Software Foundation; ////
//// either version 2.1 of the License, or (at your option) any   ////
//// later version.                                               ////
////                                                              ////
//// This source is distributed in the hope that it will be       ////
//// useful, but WITHOUT ANY WARRANTY; without even the implied   ////
//// warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR      ////
//// PURPOSE.  See the GNU Lesser General Public License for more ////
//// details.                                                     ////
////                                                              ////
//////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////
// Module:  inst_rom
// File:    inst_rom.v
// Author:  Lei Silei
// E-mail:  leishangwen@163.com
// Description: 指令儲存器
// Revision: 1.0
//////////////////////////////////////////////////////////////////////

`include "defines.v"

module inst_rom(

//	input wire clk,
	input wire ce,
	input wire[`InstAddrBus] addr, // 32 bits 位址線 (Bytes address) 實際上就是 PC
	output reg[`InstBus] inst
	
);

reg[`InstBus] inst_mem[0:`InstMemNum-1]; // 32 bits * 131071 = 4194272

initial $readmemh ( "inst_rom.data", inst_mem );

always @ (*) begin
	if (ce == `ChipDisable) begin
		inst <= `ZeroWord;
	end else begin
		inst <= inst_mem[addr[`InstMemNumLog2+1:2]];
	end
end

/// 設記憶體容量為 32 bits * 1024 => 地址寬度為 log2(1024)=10 (word address)
/// 設 OpenMIPS 給出的指令地址為 0XC = 0000 0000 0000 0000 0000 0000 0000 1100 (PC)
/// 實際上在記憶體的第 0000 0000 11 = 3 個 word => inst_mem[3]

endmodule