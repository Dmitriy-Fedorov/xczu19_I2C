`timescale 1ns / 1ps
// https://github.com/AdriaanSwan/Verilog-I2C-Slave/blob/master/Verilog/I2CTest.v

// https://github.com/mitya1337/Simple_I2C/blob/master/Verilog/i2c_slave_controller.v
module i2c_slave_controller(
	inout sda,
	inout scl
	);
	
//	localparam ADDRESS = 7'b1110100;
	localparam ADDRESS = 7'h71;
	/*
	localparam READ_ADDR = 0;
	localparam SEND_ACK = 1;
	localparam READ_DATA = 2;
	localparam WRITE_DATA = 3;
	localparam SEND_ACK2 = 4;
	localparam READ_ACK = 5;*/
	
    localparam READ_ADDR =  "READ_ADDR ";
	localparam SEND_ACK =   "SEND_ACK  ";
	localparam READ_DATA =  "READ_DATA ";
	localparam WRITE_DATA = "WRITE_DATA";
	localparam SEND_ACK2 =  "SEND_ACK2 ";
	localparam READ_ACK =   "READ_ACK  ";
	
	
	reg [7:0] addr;
	reg [7:0] counter;
	reg [79:0] state = READ_ADDR;
	reg [7:0] data_in = 0;
	reg [7:0] data_out = 8'b11001100;
	reg sda_out = 0;
	reg sda_in = 0;
	reg start = 0;
	reg write_enable = 0;
	
	assign sda = (write_enable == 1) ? sda_out : 'bz;
	
	always @(negedge sda) begin
		if ((start == 0) && (scl == 1)) begin
			start <= 1;	
			counter <= 7;
		end
	end
	
	always @(posedge sda) begin
		if ((start == 1) && (scl == 1)) begin
			state <= READ_ADDR;
			start <= 0;
			write_enable <= 0;
		end
	end
	
	always @(posedge scl) begin
		if (start == 1) begin
			case(state)
				READ_ADDR: begin
					addr[counter] <= sda;
					if(counter == 0) state <= SEND_ACK;
					else counter <= counter - 1;					
				end
				
				SEND_ACK: begin
					if(addr[7:1] == ADDRESS) begin
						counter <= 7;
						if(addr[0] == 0) begin 
							state <= READ_DATA;
						end
						else state <= WRITE_DATA;
					end
				end
				
				READ_DATA: begin
					data_in[counter] <= sda;
					if(counter == 0) begin
						state <= SEND_ACK2;
					end else counter <= counter - 1;
				end
				
				SEND_ACK2: begin
					state <= READ_ADDR;					
				end
				
				WRITE_DATA: begin
					if(counter == 0) state <= READ_ACK;
					else counter <= counter - 1;		
				end
				
				READ_ACK: begin
					state <= READ_ADDR;			
				end
				
			endcase
		end
	end
	
	always @(negedge scl) begin
		case(state)
			
			READ_ADDR: begin
				write_enable <= 0;			
			end
			
			SEND_ACK: begin
				sda_out <= 0;
				write_enable <= 1;	
			end
			
			READ_DATA: begin
				write_enable <= 0;
			end
			
			WRITE_DATA: begin
				sda_out <= data_out[counter];
				write_enable <= 1;
			end
			
			SEND_ACK2: begin
				sda_out <= 0;
				write_enable <= 1;
			end
			
			READ_ACK: begin
				write_enable <= 0;
			end
		endcase
	end
endmodule
