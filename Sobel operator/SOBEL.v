
`timescale 1ns/10ps
`define Disable 1'b0
`define Enable 1'b1

`define Free 3'b000
`define Conv 3'b001
`define Combin 3'b010
`define Outx 3'b011
`define Outy 3'b100
`define Shift 3'b101
`define OutComb 3'b110
`define Done 3'b111

`define None 2'b00
`define SobelX 2'b01
`define SobelY 2'b10
`define SobelCombine 2'b11

module  SOBEL(clk,reset,busy,ready,iaddr,idata,cdata_rd,cdata_wr,caddr_rd,caddr_wr,cwr,crd,csel	);
	input				clk;
	input				reset;
	output	reg			busy;	
	input				ready;	
	output 	reg [16:0]	iaddr;
	input  	[7:0]		idata;	
	input	[7:0]		cdata_rd;
	output	reg [7:0]	cdata_wr;
	output 	[15:0]		caddr_rd;
	output 	reg [15:0]	caddr_wr;
	output	reg			cwr,crd;
	output 	reg [1:0]	csel;
	
	//Gx
	parameter signed Gx0=16'b0000000000000001;  // 1
	parameter signed Gx1=16'b0000000000000000;  // 0
	parameter signed Gx2=16'b1111111111111111;  // -1
	parameter signed Gx3=16'b0000000000000010;  // 2
	parameter signed Gx4=16'b0000000000000000;  // 0
	parameter signed Gx5=16'b1111111111111110;  // -2
	parameter signed Gx6=16'b0000000000000001;  // 1
	parameter signed Gx7=16'b0000000000000000;  // 0
	parameter signed Gx8=16'b1111111111111111;  // -1
	//Gy
	parameter signed Gy0=16'b0000000000000001;  // 1
	parameter signed Gy1=16'b0000000000000010;  // 2
	parameter signed Gy2=16'b0000000000000001;  // 1
	parameter signed Gy3=16'b0000000000000000;  // 0
	parameter signed Gy4=16'b0000000000000000;  // 0
	parameter signed Gy5=16'b0000000000000000;  // 0
	parameter signed Gy6=16'b1111111111111111;  // -1 
	parameter signed Gy7=16'b1111111111111110;  // -2
	parameter signed Gy8=16'b1111111111111111;	// -1
	
	reg [2:0] cr_state;
	reg [2:0] next_state;
	
	reg [3:0] pnt_cnt;
	reg [16:0] pointer;
	reg [7:0] col_num;
	reg [3:0] res_cnt;
	reg signed [15:0] convx_res;
	reg signed [15:0] convy_res;
	reg conv_done;
	
	reg [15:0] caddr;
	
	reg [16:0] addr;
	always @(*) begin
		case (pnt_cnt)
			4'b0000,4'b0001,4'b0010: begin
				addr <= pointer + pnt_cnt;
			end
			4'b0011,4'b0100,4'b0101: begin
				addr <= pointer + 255 + pnt_cnt;
			end
			default: begin
				addr <= pointer + 510 + pnt_cnt;
			end
		endcase
	end
	
	wire [15:0] comb;
	assign	comb = (convx_res + convy_res +1'b1) >> 1'b1;
	
	
	
	always @(*) begin
		
		case (cr_state)
			`Free: begin
				if (ready == `Enable) begin
					next_state <= `Conv;
				end
				else begin
					next_state <= `Free;
				end
			end
			`Conv: begin
				if (conv_done == `Enable) begin
					next_state <= `Outx;
				end
				else begin
					next_state <= `Conv;
				end
			end
			`Outx: begin
				next_state <= `Outy;
			end
			`Outy: begin
				next_state <= `OutComb;
			end
			`OutComb: begin
				next_state <= `Shift;
			end
			`Shift: begin
				if (pointer == 66045) begin
					next_state <= `Done;
				end
				else begin
					next_state <= `Conv;
				end
			end
			default: begin
				next_state <= `Free;
			end
		endcase
	end
	
	always @(posedge clk or posedge reset) begin
		if (reset == `Enable) begin
			cr_state <= `Free;
			
			busy <= `Disable;
			iaddr <= 17'b0;
			crd <= `Disable;
			cwr <= `Disable;
			csel <= `None;
			
			// Convxy
			pnt_cnt <= 4'b0;
			pointer <= 17'b0;
			col_num <= 8'b0;
			res_cnt <= 4'b0;
			conv_done <= `Disable;
			convx_res <= 16'b0;
			convy_res <= 16'b0;
			
			// Outx
			caddr <= 12'b0;
		end
		else begin
			cr_state <= next_state;
			
			case (cr_state)
				`Free: begin
				end
				`Conv: begin
					busy <= `Enable;
					
					crd <= `Disable;
					cwr <= `Disable;
					csel <= `None;
					
					iaddr <= addr;
					
					if (pnt_cnt < 8) begin
						pnt_cnt <= pnt_cnt + 1'b1;
					end
					else begin
						pnt_cnt <= pnt_cnt;
					end
					
					if ((busy == `Enable)&&(cwr == `Disable)) begin
						res_cnt <= res_cnt + 1'b1;
						case (res_cnt)
							4'b0000: begin
								convx_res <= convx_res + (Gx0 * idata);
								convy_res <= convy_res + (Gy0 * idata);
							end
							4'b0001: begin
								convx_res <= convx_res + (Gx1 * idata);
								convy_res <= convy_res + (Gy1 * idata);
							end
							4'b0010: begin
								convx_res <= convx_res + (Gx2 * idata);
								convy_res <= convy_res + (Gy2 * idata);
							end
							4'b0011: begin
								convx_res <= convx_res + (Gx3 * idata);
								convy_res <= convy_res + (Gy3 * idata);
							end
							4'b0100: begin
								convx_res <= convx_res + (Gx4 * idata);
								convy_res <= convy_res + (Gy4 * idata);
							end
							4'b0101: begin
								convx_res <= convx_res + (Gx5 * idata);
								convy_res <= convy_res + (Gy5 * idata);
							end
							4'b0110: begin
								convx_res <= convx_res + (Gx6 * idata);
								convy_res <= convy_res + (Gy6 * idata);
							end
							4'b0111: begin
								convx_res <= convx_res + (Gx7 * idata);
								convy_res <= convy_res + (Gy7 * idata);
							end
							4'b1000: begin
								convx_res <= convx_res + (Gx8 * idata);
								convy_res <= convy_res + (Gy8 * idata);
							end
							default: begin
							end
						endcase
						
						if (res_cnt == 7) begin
							conv_done <= `Enable;
						end
						else begin
							conv_done <=`Disable;
						end
					end
					else begin
						res_cnt <= 4'b0;
						convx_res <= 16'b0;
						convy_res <= 16'b0;
					end
					
				end
				`Outx: begin
					cwr <= `Enable;
					csel <= `SobelX;
					caddr_wr <= caddr;
					
					if (convx_res >= 255) begin
						cdata_wr <= 255;
						convx_res <= 255;
					end
					else if (convx_res <= 0) begin
						cdata_wr <= 0;
						convx_res <= 0;
					end
					else begin
						convx_res <= convx_res;
						cdata_wr <= convx_res[7:0];
					end
				end
				`Outy: begin
					cwr <= `Enable;
					csel <= `SobelY;
					caddr_wr <= caddr;
					
					if (convy_res >= 255) begin
						convy_res <= 255;
						cdata_wr <= 255;
					end
					else if (convy_res <= 0) begin
						convy_res <= 0;
						cdata_wr <= 0;
					end
					else begin
						convy_res <= convy_res;
						cdata_wr <= convy_res[7:0];
					end
				end
				`OutComb: begin
					cwr <= `Enable;
					csel <= `SobelCombine;
					caddr_wr <= caddr;
					
					cdata_wr <= comb[7:0];
				end
				`Shift: begin
					pnt_cnt <= 4'b0;
					res_cnt <= 4'b0;
					col_num <= col_num + 1'b1;
					caddr <= caddr + 1'b1;
						
					if (col_num == 255) begin
						pointer <= pointer + 3;
					end
					else begin
						pointer <= pointer + 1'b1;
					end
				end
				
				`Done: begin
					busy <= `Disable;
				end
				default: begin
				end
			endcase
		end
	end
endmodule




