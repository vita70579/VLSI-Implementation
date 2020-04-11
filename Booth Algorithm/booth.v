`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2019/10/05 14:35:29
// Design Name: 
// Module Name: booth
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module booth(
    input [5:0] in1,
    input [5:0] in2,
    output reg [11:0] out
    );
    integer i;
    reg [5:0] temp1;
    reg [5:0] temp2;
    reg [12:0] prod;
    
    always @(in1 or in2) begin
        temp1 = in1;
        temp2 = in2;
        prod = {7'b0000_000,temp2,1'b0};
        
        for (i=0;i<6;i=i+1)
            case (prod[1:0])
            2'b00,2'b11:begin
                prod = {prod[12],prod[12:1]};
            end
            
            2'b01:begin
                prod[12:7] = prod[12:7]+temp1;
                prod = {prod[12],prod[12:1]};
            end
            
            2'b10:begin
              prod[12:7] = prod[12:7]-temp1;
              prod = {prod[12],prod[12:1]};
            end
            endcase
        out = prod[12:1];
    end
endmodule
