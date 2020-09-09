`timescale 1ns/10ps

`define Enable 1'b1
`define Disable 1'b0

/*
State
*/
`define Wait_key 4'b0000
`define Get_key 4'b0001
`define KSA 4'b0010
`define Get_plain 4'b0011
`define Write_cipher 4'b0100
`define Get_cipher 4'b0101
`define Write_plain 4'b0110
`define Done 4'b0111
`define InitSbox 4'b1000
`define KSA2 4'b1001

module RC4(clk,rst,key_valid,key_in,plain_read,plain_in_valid,plain_in,plain_write,plain_out,cipher_write,cipher_out,cipher_read,cipher_in,cipher_in_valid,done);
    input clk,rst;
    input key_valid,plain_in_valid,cipher_in_valid;
    input [7:0] key_in,cipher_in,plain_in;
    output reg done;
    output reg plain_write,cipher_write,plain_read,cipher_read;
    output reg [7:0] cipher_out,plain_out;

	reg [3:0] current_state, next_state;
	
	reg [7:0] key_mem[0:31];
	reg [4:0] key_count;
	
	reg [7:0] sbox[63:0];
	
	integer i;
	reg [5:0] j,new_k;
	
	wire [5:0] k;
	assign k = (new_k+sbox[j]+key_mem[j[4:0]]);
	
	wire [5:0] a,b,temp;
	reg[5:0] a_new,b_new;
	assign a = a_new + 1'b1;
	assign b = b_new + sbox[a];
	assign temp = sbox[a] + sbox[b];
	
	reg cycle;
	/*
	Next-state logic
	*/
	always @(*) begin
	
		case(current_state)
			`Wait_key: begin
				if (key_valid == `Enable) begin
					next_state <= `Get_key;
				end
				else begin
					next_state <= `Wait_key;
				end
			end
			`Get_key: begin
				if (key_valid == `Disable) begin
					next_state <= `InitSbox;
				end
				else begin
					next_state <= `Get_key;
				end
			end
			`InitSbox: begin
				if (cycle == 0) begin
					next_state <= `KSA;
				end
				else begin
					next_state <= `KSA2;
				end
			end
			`KSA: begin
				if (j < 63) begin
					next_state <= `KSA;
				end
				else begin
					next_state <= `Get_plain;
				end
			end
			`Get_plain: begin
				next_state <= `Write_cipher;
			end
			`Write_cipher: begin
				if (!plain_in_valid)
                    next_state <= `InitSbox;
                else
                    next_state <= `Write_cipher;
			end
			`KSA2: begin
				if ( j < 63)
                    next_state = `KSA2;
                else
                    next_state = `Get_cipher;
			end
			`Get_cipher: begin
				next_state = `Write_plain;
			end
			`Write_plain: begin
				if (!cipher_in_valid)
                    next_state = `Done;
                else
                    next_state = `Write_plain;
			end
			default : begin
                next_state = `Done;
            end
		endcase
	end
	
	/*
	State register
	*/
	always @(posedge clk or posedge rst) begin
		if (rst == `Enable) begin
			current_state <= `Wait_key;
		end
		else begin
			current_state <= next_state;
		end
	end
	
	/*
	Datapath
	*/
	always @(posedge clk or posedge rst) begin
		if (rst == `Enable) begin
			cycle <= 0;
			
			key_count <= 5'b0;
			
			j <= 6'b0;
			new_k <= 6'b0;
		
			a_new <= 6'b0;
			b_new <= 6'b0;
			
			plain_write <= 0;
            cipher_write <= 0;
            plain_read <= 0;
            cipher_read <= 0;
			done <= 0;
		end
		else begin
			case (current_state)
				`Get_key: begin
					if (key_valid) begin
						key_mem[key_count] <= key_in;
						key_count <= key_count + 1'b1;
					end
					else begin
						key_count <= 5'b0;
					end
				end
				`InitSbox: begin
                    cipher_write <= 0;
                    for ( i = 0 ; i < 64 ; i = i + 1 ) begin
                        sbox[i] <= i;
                    end
                    new_k <= 0;
					j <= 0;
					
					a_new <= 0;
					b_new <= 0;
                end
				`KSA: begin
					new_k <= k;
					sbox[j] <= sbox[k];
					sbox[k] <= sbox[j];
					j <= j + 1'b1;
				end
				`Get_plain: begin
					new_k <= 0;
					j <= 0;
					plain_read <= `Enable;
					
					cycle <= 1'b1;
				end
				`Write_cipher: begin
					if (plain_in_valid) begin
                        plain_read <= `Enable;
                        sbox[a] <= sbox[b];
                        sbox[b] <= sbox[a];
                        if ( temp == a)
                            cipher_out <= plain_in ^ sbox[b];
                        else if ( temp == b )
                            cipher_out <= plain_in ^ sbox[a];
                        else 
                            cipher_out <= plain_in ^ sbox[temp];
                        cipher_write <= `Enable;
                        a_new <= a;
                        b_new <= b;
                    end
                    else
                        plain_read <= `Disable;
				end
				`KSA2: begin
                    new_k <= k;
					sbox[j] <= sbox[k];
					sbox[k] <= sbox[j];
					j <= j + 1'b1;
                end
				`Get_cipher: begin
					new_k <= 0;
                    j <= 0;
                    cipher_read <= `Enable;
				end
				`Write_plain: begin
					if (cipher_in_valid) begin
                        cipher_read <= `Enable;
                        sbox[a] <= sbox[b];
                        sbox[b] <= sbox[a];
                        if ( temp == a)
                            plain_out <= cipher_in ^ sbox[b];
                        else if ( temp == b )
                            plain_out <= cipher_in ^ sbox[a];
                        else 
                            plain_out <= cipher_in ^ sbox[temp];
                        plain_write <= `Enable;
                        a_new <= a;
                        b_new <= b;
                    end
                    else
                        cipher_read <= `Disable;
				end
				`Done : begin
                    plain_write <= `Disable;
                    done <= `Enable;
                end
			endcase
		end
	end
	
endmodule