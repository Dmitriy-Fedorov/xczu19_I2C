`timescale 1ns / 1ps

module tb;


reg to_start = 0;
wire I2C_SDA_PL, I2C_SCL_PL;
reg clk, rst = 1;
localparam period = 20;

wire[6:0] slv_addr = 7'b1110100;
reg[7:0] reg_addr = 8'b00000001;
reg read_write = 1'b0;    // 1-read, 0-write
wire[7:0] i2c_output;
wire done_flag;
wire en;
wire[7:0] payload_out, send_buffer;

wire rx_clk, rx_data;
wire tx_clk, tx_data;
wire clk_enable, tx_enable;
wire ack;
wire[31:0] state;

//I2C_S5341 UUT(
//    .clk(clk),
//    .to_start(to_start),
//    .I2C_SDA_PL(SDA),
//    .I2C_SCL_PL(SCL)
//    );
    

/* ------- I2C main cell ------- */
I2C_S5341_seq_v2 UUT(
    .clk(clk),          // input   - 400KHz
    .rst(rst),                      // input
    .slv_addr(slv_addr),        // input [6:0]
    .payload_in(reg_addr),      // input [7:0]
    .payload_out(payload_out),     // output [7:0]
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

/*
i2c_slave slave(
    .SCL(SCL),
    .SDA(SDA)
    );*/
    

i2c_slave_controller slave(
    .scl(I2C_SCL_PL),
    .sda(I2C_SDA_PL)
    );

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
    clk = 1'b1; 
    #20; // high for 20 * timescale = 20 ns

    clk = 1'b0;
    #20; // low for 20 * timescale = 20 ns
end


always @(posedge clk)
begin
    // values for a and b
//    to_start = 0;
    #(period*5); // wait for period
    
    rst = 0;
    

//    $stop;   // end of simulation
end

always @(done_flag)
begin
    if(done_flag)
    begin
        to_start <= 0;
        $display("%6d Finished", $time );
        $display("Slave addr: %7b", slv_addr );
        $display("1-read, 0-write: %1b", read_write );
        $display("payload_in: %8b", UUT.payload_in );
        $display("payload_out: %8b", UUT.payload_out );
        #(period * 4)
        $stop;
    end
end

endmodule
