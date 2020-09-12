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
// Description: ���O�x�s��
// Revision: 1.0
//////////////////////////////////////////////////////////////////////

`include "defines.v"

module inst_rom(

//	input wire clk,
	input wire ce,
	input wire[`InstAddrBus] addr, // 32 bits ��}�u (Bytes address) ��ڤW�N�O PC
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

/// �]�O����e�q�� 32 bits * 1024 => �a�}�e�׬� log2(1024)=10 (word address)
/// �] OpenMIPS ���X�����O�a�}�� 0XC = 0000 0000 0000 0000 0000 0000 0000 1100 (PC)
/// ��ڤW�b�O���骺�� 0000 0000 11 = 3 �� word => inst_mem[3]

endmodule