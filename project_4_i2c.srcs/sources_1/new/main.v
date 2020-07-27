`timescale 1ns / 1ps

module main(
//    input clk_U42
    input wire sys_clk_p,  
    input wire sys_clk_n,
    inout wire I2C_SCL_PL, 
    inout wire I2C_SDA_PL,
    output wire I2C_RST_N_PL  //Active LOW reset input
    );
    
reg[15:0] clock_count = 16'b0;
wire[15:0] t_counter;
wire clk_ddr4_200MHz;
wire clk_I2C_400KHz;

wire[31:0] state;
wire[6:0] slv_addr;
wire[7:0] current_payload_out;
wire[7:0] current_payload_in;
wire[7:0] send_buffer;

wire done_flag;
wire ack;
wire en;
wire error;
wire rw_10;
wire trigger;

wire rx_clk, rx_data;
wire tx_clk, tx_data;
wire clk_enable, tx_enable;

wire rst_cell;

wire rst_wrapper;
wire[3:0] clk_mux;
wire[7:0] reg_addr;

/* ------- Clock ------- */
// diff buffere, works for DDR4 clock
IBUFDS #(.IBUF_LOW_PWR ("FALSE") ) u_ibufg_sys_clk (
   .I  (sys_clk_p),
   .IB (sys_clk_n),
   .O  (clk_ddr4_200MHz)  // 200MHz
);

assign clk_I2C_400KHz = clock_count[clk_mux];

/* ------- Debug ------- */
vio_0 vio_switch (
  .clk(clk_ddr4_200MHz),    // input wire clk
  .probe_out0(rst_wrapper),  // output wire [0 : 0] probe_out0
  .probe_out1(clk_mux),  // output wire [3 : 0] probe_out1
  .probe_out2(reg_addr),  // output wire [7 : 0] probe_out2
  .probe_out3(),  // output wire [6 : 0] probe_out3
  .probe_out4(I2C_RST_N_PL)
);


ila_0 ila_debug(
	.clk(clk_ddr4_200MHz), // input wire clk

	.probe0(clock_count), // input wire [15:0]  probe0  
	.probe1(clk_I2C_400KHz), // input wire [0:0]  probe1 
	.probe2({rx_data, rx_clk}), // input wire [1:0]  probe2 
	.probe3({rst_cell, ack, done_flag, en, tx_enable, trigger, error}), // input wire [5:0]  probe3 
	.probe4(current_payload_out), // input wire [7:0]  probe4 
	.probe5(send_buffer), // input wire [7:0]  probe5
	.probe6(state),     // input wire [31:0]  probe6  
	.probe7(t_counter) // input wire [15:0]  probe7 
);

/* ------- I2C tristate buffers ------- */
assign I2C_SDA_PL = tx_enable ? tx_data : 1'bZ;    // pul up resistor // if tx_enable == 1: tx_data else 1'bZ
assign rx_data = I2C_SDA_PL;
assign I2C_SCL_PL = clk_enable ? tx_clk : 1'bZ;     // pul up resistor
assign rx_clk = I2C_SCL_PL;



/* ------- I2C 1-byte wrapper ------- */
I2C_wrapper UUT(
    // essential
    .clk(clk_I2C_400KHz),
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
    .current_payload_in(current_payload_in),
    .current_payload_out(current_payload_out),
    .rw_10(rw_10),
    .rst_cell(rst_cell),
    .rst_wrapper(rst_wrapper),
    .reg_addr_driver(reg_addr),
    // debug
    .ack(ack),
    .en(en),
    .send_buffer(send_buffer),
    .state(state),
    .trigger(trigger),
    .t_counter(t_counter)
    );

/* ------- Simple 16-bit counter ------- */
always @(posedge clk_ddr4_200MHz)
begin
    clock_count <= clock_count + 1;
    /*
    wire_clk        - 200MHz
    clock_count[0]  - 100.0MHz
    clock_count[1]  - 50.0MHz
    clock_count[2]  - 25.0MHz
    clock_count[3]  - 12.5MHz
    clock_count[4]  - 6.25MHz
    clock_count[5]  - 3.125MHz
    clock_count[6]  - 1.5625MHz
    clock_count[7]  - 781.25KHz
    clock_count[8]  - 390.625KHz
    */
    
end

endmodule