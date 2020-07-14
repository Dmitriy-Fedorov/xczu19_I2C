`timescale 1ns / 1ps

module main(
//    input clk_U42
    input wire sys_clk_p,  
    input wire sys_clk_n,
    inout wire I2C_SCL_PL, 
    inout wire I2C_SDA_PL
    );
    
reg[15:0] clock_count = 16'b0;
wire clk_ddr4_200MHz;
wire clk_I2C_400KHz;


//reg[7:0] reg_addr = 8'b00000010;
//reg read_write = 1'b0;    // 1-read, 0-write
wire[31:0] state;
wire[6:0] slv_addr = 7'b1110100;
wire[7:0] payload_out;
wire[7:0] send_buffer;

wire done_flag;
wire ack;
wire en;

wire rx_clk, rx_data;
wire tx_clk, tx_data;
wire clk_enable, tx_enable;



wire rst;
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
  .probe_out0(rst),  // output wire [0 : 0] probe_out0
  .probe_out1(clk_mux),  // output wire [3 : 0] probe_out1
  .probe_out2(reg_addr)  // output wire [7 : 0] probe_out2
);


ila_0 ila_debug (
	.clk(clk_ddr4_200MHz), // input wire clk

	.probe0(clock_count), // input wire [15:0]  probe0  
	.probe1(clk_I2C_400KHz), // input wire [0:0]  probe1 
	.probe2({rx_data, rx_clk}), // input wire [1:0]  probe2 
	.probe3({rst, ack, done_flag, en, tx_enable, clk_enable}), // input wire [5:0]  probe3 
	.probe4(payload_out), // input wire [7:0]  probe4 
	.probe5(send_buffer), // input wire [7:0]  probe5
	.probe6(state)     // input wire [31:0]  probe0  
);

/* ------- I2C tristate buffers ------- */
assign I2C_SDA_PL = tx_enable ? tx_data : 1'bZ;    // pul up resistor // if tx_enable == 1: tx_data else 1'bZ
assign rx_data = I2C_SDA_PL;
assign I2C_SCL_PL = clk_enable ? tx_clk : 1'bZ;     // pul up resistor
assign rx_clk = I2C_SCL_PL;



/* ------- I2C main cell ------- */
I2C_S5341_seq_v2 I2C_cell(
    .clk(clk_I2C_400KHz),          // input   - 400KHz
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