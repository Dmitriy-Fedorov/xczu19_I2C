`timescale 1ns / 1ps

module tb_wrapper;


wire I2C_SDA_PL, I2C_SCL_PL;
reg clk;
wire rst_cell;
reg rst_wrapper = 1;
localparam period = 20;

wire done_flag;
wire en_wrapper;
wire[7:0] current_data_out, current_data_in, send_buffer;
wire[7:0] reg_addr;
wire[6:0] slv_addr;

wire rx_clk, rx_data;
wire tx_clk, tx_data;
wire clk_enable, tx_enable;
wire ack;
wire error;
wire rw_10;
//wire w2_mode;
wire trigger;
wire[31:0] state;
wire[31:0] t_counter;


I2C_wrapper UUT(
    // essential
    .clk(clk),
    // I2C pass throuth
    .rx_data(rx_data),
    .rx_clk(rx_clk),
    .tx_data(tx_data),
    .tx_clk(tx_clk),
    .tx_enable(tx_enable),
    .clk_enable(clk_enable),
    
    .error(error),
    .done_flag(done_flag),
    
    // control
    .slv_addr(slv_addr),
    .reg_addr(reg_addr),
    .current_data_in(current_data_in),
    .current_data_out(current_data_out),
    .rw_10(rw_10),
    .rst_cell(rst_cell),
    .rst_wrapper(rst_wrapper),
    // debug
    .ack(ack),
    .en(en_wrapper),
    .send_buffer(send_buffer),
    .state(state),
    .trigger(trigger),
    .t_counter(t_counter)
    );
    

i2c_slave_controller slave_U46(
    .scl(I2C_SCL_PL),
    .sda(I2C_SDA_PL)
    );
    
//i2c_slave_controller #(.ADDRESS(7'h71), .DATA(8'h02)) slave_U53(
//    .scl(I2C_SCL_PL),
//    .sda(I2C_SDA_PL)
//    );

pullup (I2C_SDA_PL);
pullup (I2C_SCL_PL);

// if tx_enable == 1 then tx_data else rx_data
assign I2C_SDA_PL = tx_enable ? tx_data : 1'bZ;    // pul up resistor  
assign rx_data = I2C_SDA_PL;
assign I2C_SCL_PL = clk_enable ? tx_clk : 1'bZ;     // pul up resistor
assign rx_clk = I2C_SCL_PL;


// note that sensitive list is omitted in always block
// therefore always-block run forever
// clock period = 2 ns
always 
begin
    clk = 1'b0; 
    #20; // high for 20 * timescale = 20 ns

    clk = 1'b1;
    #20; // low for 20 * timescale = 20 ns
end


always @(posedge clk)
begin
    #(period*5); // wait for period
    
    rst_wrapper = 0;
//    $stop;   // end of simulation
end

always @(done_flag)
begin
    if(done_flag)
    begin
        $display("%6d Finished", $time );
        $display("Slave addr: %7b", slv_addr );
        $display("payload_in: %8b", UUT.current_data_in );
        $display("payload_out: %8b", UUT.current_data_out );
//        #(period * 4)
//        $stop;
    end
end

endmodule
