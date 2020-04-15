`timescale 1ns / 10ps
module div(out, in1, in2, dbz);
parameter width = 8;
input  	[width-1:0] in1; // Dividend
input  	[width-1:0] in2; // Divisor
output  reg [width-1:0] out; // Quotient
output reg dbz;

reg [2*width-1:0] temp1;
reg [width-1:0] temp2;

reg [2*width-1:0] remainder;	// 16 bits remainder
reg [width-1:0] divisor;	// 8 bits divisor



integer i;


always @(in1 or in2) begin

	temp1 <= in1;
	temp2 <= in2;

end
always @(temp1 or temp2) begin

	remainder = {7'd0,temp1,1'd0};
	divisor = temp2;
	
	if (divisor != 8'd0) begin
	
		dbz = 1'd0;
	
		for (i=0;i<width;i=i+1) begin
	
			
	
			if(remainder[2*width-1:width]<divisor) begin
			
				remainder = {remainder[2*width-2:0],1'd0};
			
			end
			else begin
			
				remainder[2*width-1:width] = remainder[2*width-1:width]-divisor;
				remainder = {remainder[2*width-2:0],1'd1};
			
			end
		
		end
		
		remainder[2*width-1:width] = {1'd0,remainder[2*width-1:width+1]};
		out = remainder[width-1:0];
	
	end
	else begin
		dbz = 1'd1;
	end
	
end



endmodule