`timescale 1ns / 1ps



module I2C_S5341_seq_v2(
    // essential
    input wire clk,
    input wire[6:0] slv_addr,
    input wire[7:0] payload_in,
    output reg[7:0] payload_out,
    
    input wire rst,
    input wire rw_10,
    output reg error = 0,
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
    


//localparam start_1 = 2;
//localparam start_2 = 140; //82;
localparam t_start = 2;
localparam READ_RX = 0;
localparam WRITE_TX = 1;
localparam I2C_READ = 1'b1;
localparam I2C_WRITE = 1'b0;

reg[7:0] main_counter = 8'hff;  
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
                flag_clk_count <= 0;
                clk_counter <= 0;
            end
            offset + 4:
            begin
                done_flag <= 1;
            end
            offset + 5:
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
//    output [7:0] buffer;
    
    begin
    case (main_counter)
        offset:
        begin 
            $display("%6d Recieving payload", $time);
            payload_out[7] <= rx_data;
            state <= "READ";
        end
        offset + 4:
        begin 
            payload_out[6] <= rx_data;
        end
        offset + 8:
        begin 
            payload_out[5] <= rx_data;
        end
        offset + 12:
        begin 
            payload_out[4] <= rx_data;
        end
        offset + 16:
        begin 
            payload_out[3] <= rx_data;
        end
        offset + 20:
        begin 
            payload_out[2] <= rx_data;
        end
        offset + 24:
        begin 
            payload_out[1] <= rx_data;
        end
        offset + 28:
        begin 
            payload_out[0] <= rx_data;
            $display("%6d Recieved payload, %8b", $time,  {payload_out[7:1], rx_data} );
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
                error <= 1;
                $display("%6d NACK %1b recieved", $time, ack );
//                main_counter <= 32'd77;
            end
        end
        offset + 4:
        begin
            tx_enable <= tx_enable_flag;
            ack <= 1;
            error <= 0;
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
        main_counter <= 8'hff;
        clk_counter <= 0;
        clk_enable <= 0;
        tx_enable <= 0;
        en <= 1'b1;
        state <= "IDLE";
        done_flag <= 0;
    end
    else
    begin
        if(en)
        begin
            main_counter <= main_counter + 1;
            if (flag_clk_count)
                clk_counter <= clk_counter + 1;
        end
        if (~rw_10)
        begin
            // select register
            do_start(t_start);
            do_send(t_start + 2, {slv_addr, I2C_WRITE});
            read_ack(t_start + 33, WRITE_TX);
            do_send(t_start + 38, payload_in);
            read_ack(t_start + 69, WRITE_TX);
            do_stop(t_start + 75);
        end
        else
        begin
            // read stage
            do_start(t_start);
            do_send(t_start + 2, {slv_addr, I2C_READ});
            read_ack(t_start + 33, READ_RX);
            do_read(t_start + 40);
            send_nack(t_start + 69, WRITE_TX);
            do_stop(t_start + 75);
        end
        
        case (main_counter)
            /*
            main_counter % 4 == 2 -> possedge
            main_counter % 4 == 3 -> positive
            main_counter % 4 == 0 -> negedge
            main_counter % 4 == 1 -> zero
            */    
        t_start + 90:
        begin
            en <= 0;
        end
        
        endcase
    end
end
endmodule
