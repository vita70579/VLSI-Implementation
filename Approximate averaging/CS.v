`timescale 1ns/10ps
module CS(Y, X, reset, clk);
parameter n = 9;

input clk, reset; 
input 	[7:0] X;
output 	reg [9:0] Y;

reg [7:0] temp;
reg [9:0] mem [0:8];

real result;
real sum = 0;
real appravg = 0;
real avg = 0;
real amt;

integer cnt = 0,pcnt = 0;
integer i,j,k;

always @(negedge clk) begin
temp[7:0] = X;
    if ((reset==0) && (cnt<n)) begin
        mem[cnt] = {2'b00,temp};
        sum = sum + mem[cnt];
        avg = $floor(sum/n);
        cnt = cnt+1;
    end 
        
    else if((reset==0) && (cnt>=n)) begin
        sum = sum - mem[0];
        
        for(i = 0 ; i < n-1 ; i = i+1) begin
                mem[i] = mem[i+1];
            end
            mem[n-1] = {2'b00,temp};
            sum = sum + mem[n-1];
            avg = $floor(sum/n);
        end
    amt = 1023;
    for (j=0 ; j<n ; j=j+1) begin
        if((avg - mem[j] >= 0) && (avg - mem[j] < amt)) begin
            amt = avg - mem[j];
            appravg = mem[j];
        end
    end

    if(cnt>=n) begin
        result = ((9*appravg)+sum)/(n-1);
        Y = $floor(result);
    end
end

always @(posedge reset) begin
    
    if(reset) begin
        Y <= 9'bxxx_xxx_xxx;
    end
end
endmodule


