`timescale 1ns / 1ps

module I2C_wrapper(
    // essential
    input wire clk,
    // I2C pass throuth
    input wire rx_data,
    input wire rx_clk,
    output wire tx_data,
    output wire tx_clk,
    output wire tx_enable,
    output wire clk_enable,
    
    output wire error,
    output wire done_flag,
    
    
    // control
    output reg[6:0] slv_addr,
    output reg[7:0] current_payload_in,
    output wire[7:0] current_payload_out,
    output reg rw_10,
    output reg rst_cell,
    input wire rst_wrapper,
    // debug
    output wire ack,
    output wire en,
    output wire[7:0] send_buffer,
    output wire[31:0] state,
    output reg trigger
    );
    

/* ------- I2C main cell ------- */
I2C_S5341_seq_v2 I2C_cell(
    .clk(clk),                              // input   - 400KHz
    .slv_addr(slv_addr),                    // input [6:0]
    .payload_in(current_payload_in),        // input [7:0]
    .payload_out(current_payload_out),      // output [7:0]
    
    .rst(rst_cell),                         // input
    .error(error),
    .rw_10(rw_10),
    .done_flag(done_flag),       // output
       
    .rx_data(rx_data),
    .rx_clk(rx_clk),
    .tx_data(tx_data),
    .tx_clk(tx_clk),
    .tx_enable(tx_enable),
    .clk_enable(clk_enable),
    
    .en(en),                        
    .ack(ack), 
    .send_buffer(send_buffer),
    .state(state)
    );
    
reg[7:0] byte_index;  
reg[15:0] t_counter = 16'h00;
reg wrapper_enable;
localparam t_cycle = 100;  // how many clock ticks does it takes to send 1-byte
localparam U53_slave_addr = 7'h71;  // 7'b1110001;
localparam U46_slave_addr = 7'h74;  // 7'b1110100;


task send_byte;
    input [15:0] index;
    input [6:0] addr;
    input [7:0] payload;
    begin
        case (t_counter)
            t_cycle * index:
            begin
                slv_addr <= addr;                   // i2c slave addr
                current_payload_in <= payload;      // payload to transmit
                rw_10 <= 0;                         // write enable
            end
            t_cycle * index + 1:
            begin
                rst_cell <= 0;                      // makes i2c cell active
            end
            t_cycle * (index + 1) - 10:
            begin
                rst_cell <= 1;                      // makes i2c cell inactive and resets
            end
        endcase
    end
endtask

task read_byte;
    input [15:0] index;
    input [6:0] addr;
    begin
        case (t_counter)
            t_cycle * index:
            begin
                slv_addr <= addr;                   // i2c slave addr
                current_payload_in <= 0;            // dummy payload
                rw_10 <= 1;                         // read enable
            end
            t_cycle * index + 1:
            begin
                rst_cell <= 0;                      // makes i2c cell active
            end
            t_cycle * (index + 1) - 10:
            begin
                rst_cell <= 1;
            end
        endcase
    end
endtask


task stop_finish;
    input [15:0] index;
    begin
        case (t_counter)
        t_cycle*index + 1:
        begin
            wrapper_enable <= 0;    // stops t_counter in order to prevent overflow
        end
        endcase
    end 
endtask


always @(posedge clk)
begin
    if (rst_wrapper)
    begin
        current_payload_in <= 8'h00;
        rst_cell <= 1;
        wrapper_enable <= 1;
        trigger <= 0;
        byte_index <= 8'h0;
    end
    else
    begin
        if (wrapper_enable)
        begin
            t_counter <= t_counter + 1;
        end
        
        read_byte(16'd0, U53_slave_addr);
        send_byte(16'd1, U53_slave_addr, 8'h02); // U53 activate line number 1
        read_byte(16'd2, U53_slave_addr);
        
        stop_finish(16'd3);
    end
end

endmodule
