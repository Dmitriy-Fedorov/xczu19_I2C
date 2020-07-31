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
    output reg[7:0] reg_addr,
    output reg[7:0] current_data_in,
    output wire[7:0] current_data_out,
    output reg rw_10,
    output reg rst_cell,
    input wire rst_wrapper,
    input wire[7:0] reg_addr_driver,
    // debug
    output wire ack,
    output wire en,
    output wire[7:0] send_buffer,
    output wire[31:0] state,
    output reg trigger,
    output reg[31:0] t_counter = 32'h00,
    output reg[15:0] pointer = 15'd0,  // RAM index pointer
    output wire[7:0] RAM_addr,
    output wire[7:0] RAM_data
    );
    

reg assert_error = 0;
reg w2_mode;
wire ack_error;
assign error = assert_error | ack_error;
reg wrapper_enable;

localparam t_cycle = 8'd150;        // how many clock ticks does it takes to send 1-byte
localparam U53_slave_addr = 7'h71;  // 7'b1110001;
localparam U46_slave_addr = 7'h74;  // 7'b1110100;

/* ------- I2C main cell ------- */
I2C_S5341_seq_v2 #(.t_cycle(t_cycle)) I2C_cell  (
    .clk(clk),                              // input   - 400KHz
    .slv_addr(slv_addr),                    // input [6:0]
    .reg_addr(reg_addr),
    .data_in(current_data_in),        // input [7:0]
    .data_out(current_data_out),      // output [7:0]
    
    .rst(rst_cell),                         // input
    .error(ack_error),
    .rw_10(rw_10),
    .w2_mode(w2_mode),
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

/* ------- ROM memory cell ------- */
ROM memory(
//    .clk(clk),
    .i(pointer),
    .addr_i(RAM_addr),
    .data_i(RAM_data)
);


/* ------- Task defenitions ------- */
task send_byte2;
    input [15:0] index;
    input [6:0] addr;
    input [7:0] data;
    begin
        case (t_counter)
            t_cycle * index:
            begin
                slv_addr <= addr;                   // i2c slave addr
                reg_addr <= 8'h00;                  // dummy value
                current_data_in <= data;            // payload to transmit
                rw_10 <= 0;                         // write enable
                w2_mode <= 1;                       // 2-staged mode select
                $display("%6d Send_byte2 %2h:%2h", $time ,addr, data);
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

task send_byte3_inc_pointer;
    input [15:0] index;
    input [6:0] s_addr;
    input [7:0] r_addr;
    input [7:0] data;
    begin
        case (t_counter)
            t_cycle * index:
            begin
                slv_addr <= s_addr;                 // i2c slave addr
                reg_addr <= r_addr;                 // register adress u U46
                current_data_in <= data;            // payload to transmit
                rw_10 <= 0;                         // write enable
                w2_mode <= 0;                       // 3-staged mode select
            end
            t_cycle * index + 1:
            begin
                rst_cell <= 0;                      // makes i2c cell active
            end
            t_cycle * (index + 1) - 10:
            begin
                rst_cell <= 1;                      // makes i2c cell inactive and resets
                pointer <= pointer + 1;
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
                reg_addr <= 8'h80;
                current_data_in <= 0;               // dummy payload
                rw_10 <= 1;                         // read enable
                // w2_mode <= x;                    // dont care
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

task do_trigger;
    input [15:0] t;
    begin
        case (t_counter)
        t:
        begin
            trigger <= 1; 
        end
        t + 1:
        begin
            trigger <= 0; 
        end 
        endcase
    end 
endtask

task assert_current_data_out;
    input [15:0] index;
    input [7:0] assert_equal;
    begin
        case (t_counter)
        t_cycle * (index + 1) - 10:
        begin
            if (current_data_out != assert_equal)
            begin
                assert_error <= 1;
            end
        end
        t_cycle * (index + 1) - 9:
        begin
            assert_error <= 0;
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
            rst_cell <= 1;
            $stop;
        end
        default:
        begin
            if(error)
            begin
                wrapper_enable <= 0;    // stops t_counter in case of error
            end
        end
        endcase
    end 
endtask

/* ------- Main logic control ------- */
localparam offset = 4;

always @(posedge clk)
begin
    if (rst_wrapper)
    begin
        current_data_in <= 8'h00;
        rst_cell <= 1;
        wrapper_enable <= 1;
        trigger <= 0;
        t_counter <= 0;
        pointer <= 0;
    end
    else
    begin
        if (wrapper_enable)
        begin
            t_counter <= t_counter + 1;
        end
        
        send_byte2(16'd0, U53_slave_addr, 8'h02); // U53 activate line number 1
        read_byte(16'd1, U53_slave_addr);
        assert_current_data_out(16'd1, 8'h02);
        
        
        send_byte2(16'd2, U46_slave_addr, reg_addr_driver); // U46 select register to read by sending its addr
        read_byte(16'd3, U46_slave_addr);
    
        do_trigger(t_cycle*400);

        if ((t_cycle*offset >= 0) & (pointer < 400))
        begin
            $display("%6d Send_byte3 %d", $time, pointer);
            send_byte3_inc_pointer(pointer+offset, U46_slave_addr, RAM_addr, RAM_data);
        end
        
        stop_finish(400+offset);
        
    end
end

endmodule
