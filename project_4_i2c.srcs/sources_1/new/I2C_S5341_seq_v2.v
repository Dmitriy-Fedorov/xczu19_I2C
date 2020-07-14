`timescale 1ns / 1ps



module I2C_S5341_seq_v2(
    // essential
    input wire clk,
    input wire rst,
    input wire[6:0] slv_addr,
    input wire[7:0] payload_in,
    output reg[7:0] payload_out,
    output reg done_flag,
    // I2C
    input wire rx_data,
    input wire rx_clk,
    output reg tx_data,
    output wire tx_clk,
    output reg tx_enable,
    output reg clk_enable,
    //debug
    output reg ack = 1,
    output reg en,
    output reg[7:0] send_buffer,
    output reg[31:0] state = "IDLE"
    );
    


localparam start_1 = 2;
localparam start_2 = 84; //82;
localparam READ_RX = 0;
localparam WRITE_TX = 1;
localparam I2C_READ = 1'b1;
localparam I2C_WRITE = 1'b0;

reg[31:0] main_counter = 32'hffffffff;  
reg[7:0] clk_counter = 8'h00;  
reg flag_clk_count = 0;

assign tx_clk = clk_counter[1];


task do_start;
    input [31:0] offset;
    begin
        case (main_counter)
            offset:
            begin 
                $display("%6d Start Condition", $time );
                tx_enable <= 1;
                tx_data <= 0; 
                state <= "STRT";
            end
            offset + 1:
            begin 
                clk_enable <= 1;
                tx_data <= 0; 
                flag_clk_count <= 1;
            end
        endcase
    end
endtask

task do_stop;
    input [31:0] offset;
    begin
        case (main_counter)
            // Stopping
            offset:
            begin
                $display("%6d Stopping", $time );
                clk_enable <= 0;
                tx_enable <= 1;
                tx_data <= 0;
                state <= "STOP";
            end
            offset + 1:
            begin
                tx_enable <= 0;
            end
            offset + 2:
            begin
                tx_enable <= 0;
                done_flag <= 1;
                flag_clk_count <= 0;
                clk_counter <= 0;
            end
            offset + 3:
            begin
                done_flag <= 0;
                state <= "IDLE";
            end
        endcase
    end
endtask

task do_send;
    input [31:0] offset;
    input [7:0] buffer;
    
    begin
    case (main_counter)
        offset:
        begin 
            $display("%6d Sending payload, %8b", $time,  buffer);
            send_buffer <= buffer;  // debug
            tx_data <= buffer[7];
            state <= "SEND";
        end
        offset + 4:
        begin 
            tx_data <= buffer[6];
        end
        offset + 8:
        begin 
            tx_data <= buffer[5];
        end
        offset + 12:
        begin 
            tx_data <= buffer[4];
        end
        offset + 16:
        begin 
            tx_data <= buffer[3];
        end
        offset + 20:
        begin 
            tx_data <= buffer[2];
        end
        offset + 24:
        begin 
            tx_data <= buffer[1];
        end
        offset + 28:
        begin 
            tx_data <= buffer[0];
        end
        offset + 32:
        begin 
            tx_data <= 1'b0;
            send_buffer <= 0;  // debug
        end
    endcase
    end
endtask

task do_read;
    input [31:0] offset;
    output [7:0] buffer;
    
    begin
    case (main_counter)
        offset:
        begin 
            $display("%6d Recieving payload", $time);
            buffer[7] <= rx_data;
            state <= "READ";
        end
        offset + 4:
        begin 
            buffer[6] <= rx_data;
        end
        offset + 8:
        begin 
            buffer[5] <= rx_data;
        end
        offset + 12:
        begin 
            buffer[4] <= rx_data;
        end
        offset + 16:
        begin 
            buffer[3] <= rx_data;
        end
        offset + 20:
        begin 
            buffer[2] <= rx_data;
        end
        offset + 24:
        begin 
            buffer[1] <= rx_data;
        end
        offset + 28:
        begin 
            buffer[0] <= rx_data;
            $display("%6d Recieved payload, %8b", $time,  {buffer[7:1], rx_data} );
        end
    endcase
    end
endtask

task read_ack;
    input [31:0] offset;
    input tx_enable_flag;  // controls state of tx_enable after acknowledgment is done
    
    begin
    case (main_counter)
        // Wait for ACK
        offset:
        begin 
            $display("%6d Waiting for ACK", $time );
            tx_enable <= 0;
            state <= "ACK";
        end
        offset + 2:
        begin 
            ack <= rx_data;
        end
        offset + 3:
        begin 
            if (~ack)
            begin
                $display("%6d ACK %1b recieved", $time, ack );
            end
            else
            begin
                $display("%6d NACK %1b recieved", $time, ack );
//                main_counter <= 32'd77;
            end
        end
        offset + 4:
        begin
            tx_enable <= tx_enable_flag;
            ack <= 1;
        end
    endcase
    
    end
endtask

task send_nack;
    input [31:0] offset;
    input tx_enable_flag;  // controls state of tx_enable after acknowledgment is done
    begin
        case (main_counter)
        offset:
        begin
            $display("%6d Pretend to send NACK", $time );
            state <= "NACK";
        end
        offset + 4:
        begin
            tx_enable <= tx_enable_flag;
            ack <= 1;
        end
        endcase
    end
endtask

always @(posedge clk)
begin
    if (rst)
    begin
        main_counter <= 32'hffffffff;
        clk_counter <= 0;
        clk_enable <= 0;
        tx_enable <= 0;
        en <= 1'b1;
        state <= "IDLE";
    end
    else
    begin
        if(en)
        begin
            main_counter <= main_counter + 1;
            if (flag_clk_count)
                clk_counter <= clk_counter + 1;
        end
        // select register
        do_start(start_1);
        do_send(start_1 + 2, {slv_addr, I2C_WRITE});
        read_ack(start_1 + 33, WRITE_TX);
        do_send(start_1 + 38, payload_in);
        read_ack(start_1 + 69, WRITE_TX);
        do_stop(start_1 + 75);
        
        // read stage
        do_start(start_2);
        do_send(start_2 + 2, {slv_addr, I2C_READ});
        read_ack(start_2 + 33, READ_RX);
        do_read(start_2 + 39, payload_out);
        send_nack(start_2 + 69, WRITE_TX);
        do_stop(start_2 + 75);
        
        
        case (main_counter)
        32'hffffffff:
        begin
            clk_enable <= 0;
            tx_enable <= 0;
        end          
        start_2 + 100:
        begin
            en <= 0;
        end
        
        endcase
    end
end
endmodule
