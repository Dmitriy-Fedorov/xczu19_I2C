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
    output wire[31:0] state
    );
    

/* ------- I2C main cell ------- */
I2C_S5341_seq_v2 I2C_cell(
    .clk(clk),          // input   - 400KHz
    .slv_addr(slv_addr),        // input [6:0]
    .payload_in(current_payload_in),      // input [7:0]
    .payload_out(current_payload_out),     // output [7:0]
    
    .rst(rst_cell),                      // input
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
    
reg[7:0] wrapper_counter;  
reg wrapper_enable = 0;

always @(negedge done_flag, posedge done_flag)
begin
    if(wrapper_enable & (~rst_wrapper))
    begin
        wrapper_counter <= wrapper_counter + 1;
    end
    
end

always @(posedge clk)
begin
    if (rst_wrapper)
    begin
        wrapper_counter <= 8'h0;
        current_payload_in <= 8'h00;
        rst_cell <= 1;
        wrapper_enable <= 1;
    end
    else
    begin
        
        case (wrapper_counter)
        8'd0:
        begin
            // read U53 register
            rst_cell <= 0;
            slv_addr <= 7'h71;
            current_payload_in <= 0;
            rw_10 <= 1;
        end
        8'd1:
        begin
            rst_cell <= 1;
        end
        
        8'd2:
        begin
            // write U53 register
            rst_cell <= 0;
            slv_addr <= 7'h71;
            current_payload_in <= 8'h02;  // U53 line number 1
            rw_10 <= 0;
        end
        8'd3:
        begin
            rst_cell <= 1;
        end
        
        8'd4:
        begin
            // read U53 register
            rst_cell <= 0;
            slv_addr <= 7'h71;
            current_payload_in <= 8'h00;
            rw_10 <= 1;
        end
        8'd5:
        begin
            rst_cell <= 1;
        end
        
        
        
        8'd6:
        begin
            wrapper_enable <= 0;
        end
        endcase
    end
end

endmodule
