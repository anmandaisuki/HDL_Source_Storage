`timescale 1ps / 100fs
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2023/06/24 07:39:53
// Design Name: 
// Module Name: tb
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module tb();

parameter REFCLK_FREQ           = 200.0; // MHz
parameter SYSCLK_FREQ           = 166.0; //MHz
localparam real REFCLK_PERIOD_PS = (1000000.0/(2*REFCLK_FREQ));
localparam real SYSCLK_PERIOD_PS = (1000000.0/(2*SYSCLK_FREQ));

localparam  SYSCLK_FREQ_MHZ = 166 ; 
localparam  REFCLK_FREQ_MHZ = 200 ;
localparam  RESET_HOLD_TIME = 100 ; 

// int SYSCLK_PERIOD_NS = (1/(SYSCLK_FREQ_MHZ))*10^3*(1/2);
localparam SYSCLK_PERIOD_NS = 3000;
// int REFCLK_FREQ_PS_NS = (1/(REFCLK_FREQ_MHZ))*10^3*(1/2);

localparam WRITE_DATA = 128'h1;
localparam WRITE_MASK = 16'h0;



    // wire between MIG and DDR3
    wire rst_n          ;
    wire ck             ;
    wire ck_n           ;
    wire cke            ;
    wire cs_n           ;
    wire ras_n          ;
    wire cas_n          ;
    wire we_n           ;
    wire [1:0] dm_tdqs  ;
    wire [2:0] ba       ;
    wire [13:0] addr    ;
    wire [15:0] dq      ;
    wire [1:0] dqs      ;
    wire [1:0] dqs_n    ;
    wire tdqs_n         ;
    wire odt            ;

    // wire between MIG and user interface
    //input
    reg      sys_clk_i;
    reg      clk_ref_i;
    reg[27:0] app_addr;
    reg[2:0]   app_cmd;
    reg         app_en;
    reg [127:0] app_wdf_data;
    reg          app_wdf_end;
    reg [15:0] app_wdf_mask;
    reg app_wdf_wren;

    reg app_sr_req ;
    reg app_ref_req;
    reg app_zq_req ;

    reg sys_rst;

    //output
    wire ui_clk   ;
    wire[127:0] app_rd_data;
    wire app_rd_data_end   ;
    wire app_rd_data_valid ;
    wire app_rdy           ;
    wire app_wdf_rdy       ;

    wire app_sr_active      ;  
    wire app_ref_ack        ;  
    wire app_zq_ack         ;  
    wire ui_clk             ;  
    wire ui_clk_sync_rst    ;  
    wire init_calib_complete;  
    wire[11:0] device_temp  ;

// generate sys_clk and ref_clk
task clk_gen();
    sys_clk_i = 0;
    forever #(SYSCLK_PERIOD_PS) sys_clk_i =! sys_clk_i;
endtask

task ref_clk_gen();
    clk_ref_i = 0;
    forever #(REFCLK_PERIOD_PS) clk_ref_i =! clk_ref_i;
endtask
// reset process in the case of rst active high
task rst_gen_active_high();
    sys_rst = 1;
    #(200000);//200ns
    sys_rst = 0;
endtask
// reset process in the case of rst active low
task rst_gen_active_low();
    sys_rst = 0;
    #(200000);//200ns
    sys_rst = 1;
endtask

task write_ddr3();
    input [27:0] addr;
    input [127:0] w_data;
    begin
        app_addr = addr;
        app_wdf_data = w_data;
        app_en    = 1'b1;
        app_cmd = 3'b000;
        app_wdf_wren = 1'b1;
        app_wdf_end  = 1'b1; 
        app_wdf_mask = WRITE_MASK;
        #(SYSCLK_PERIOD_PS*2);
        app_en = 1'b0;
        app_wdf_end = 1'b0;
        app_wdf_wren = 1'b0;
    end
endtask

task write_ddr3_v2();
    input [27:0] addr;
    input [127:0] w_data;
    begin
        app_addr = addr;
        app_wdf_data = w_data;
        app_en    = 1'b1;
        app_cmd = 3'b000;
        app_wdf_wren = 1'b0;
        app_wdf_end  = 1'b0; 
        app_wdf_mask = WRITE_MASK;
        #(SYSCLK_PERIOD_PS*2);
        app_wdf_wren = 1'b1;
        app_wdf_end  = 1'b1; 
        #(SYSCLK_PERIOD_PS*2);
        app_en = 1'b0;
        app_wdf_end = 1'b0;
        app_wdf_wren = 1'b0;
    end
endtask

task write_ddr3_v3();
    input [27:0] addr;
    input [127:0] w_data;
    begin
        app_addr = addr;
        app_wdf_data = w_data;
        app_en    = 1'b1;
        app_cmd = 3'b000;
        app_wdf_wren = 1'b0;
        app_wdf_end  = 1'b0; 
        app_wdf_mask = WRITE_MASK;
        #(SYSCLK_PERIOD_PS*2);
        app_wdf_wren = 1'b1;
        app_wdf_end  = 1'b1; 
        #(SYSCLK_PERIOD_PS*10);
        app_en = 1'b0;
        app_wdf_end = 1'b0;
        app_wdf_wren = 1'b0;
    end
endtask

task read_ddr3();
    input [27:0] addr;
    begin
        app_addr = addr;
        app_cmd = 3'b001;
        app_en = 1'b1;
         #(SYSCLK_PERIOD_PS*6);
        app_en = 1'b0;
    end
endtask


 mig_7series_0 mig (

  // Inouts
  .ddr3_dq(dq),
  .ddr3_dqs_n(dqs_n),
  .ddr3_dqs_p(dqs),
  // Outputs
  .ddr3_addr(addr),
  .ddr3_ba(ba),
  .ddr3_ras_n(ras_n),
  .ddr3_cas_n(cas_n),
  .ddr3_we_n(we_n),
  .ddr3_reset_n(rst_n),
  .ddr3_ck_p(ck),
  .ddr3_ck_n(ck_n),
  .ddr3_cke(cke),
  .ddr3_cs_n(cs_n),
  .ddr3_dm(dm_tdqs),
  .ddr3_odt(odt),

  // Inputs

  // Single-ended system clock
  .sys_clk_i(sys_clk_i),
  // Single-ended iodelayctrl clk (reference clock)
  .clk_ref_i(clk_ref_i),
  // user interface signals
  .app_addr(app_addr),
  .app_cmd(app_cmd),
  .app_en(app_en),
  .app_wdf_data(app_wdf_data),
  .app_wdf_end(app_wdf_end),
  .app_wdf_mask(app_wdf_mask),
  .app_wdf_wren(app_wdf_wren),

  .app_rd_data(app_rd_data),
  .app_rd_data_end(app_rd_data_end),
  .app_rd_data_valid(app_rd_data_valid),
  .app_rdy(app_rdy),
  .app_wdf_rdy(app_wdf_rdy),

  .app_sr_req (1'b0),
  .app_ref_req(1'b0),
  .app_zq_req (1'b0),
  .app_sr_active      (app_sr_active      ),
  .app_ref_ack        (app_ref_ack        ),
  .app_zq_ack         (app_zq_ack         ),
  .ui_clk             (ui_clk             ),
  .ui_clk_sync_rst    (ui_clk_sync_rst    ),
  .init_calib_complete(init_calib_complete),
  .device_temp        (device_temp)        ,
  .sys_rst(sys_rst)     // determined by GUI mig setting
  );

  ddr3_model ddr (.*);

  initial begin
    // fork join is the statement for pararell process. Suffix of join determine when to come out of fork-join process. 
    // fork join_none: next step starts right after this. 
    // fork join     : next step starts after finishing fork-join process. If fork-join process has forever statement, the process never get out of fork-join. 
    fork
        clk_gen();
        ref_clk_gen();
        rst_gen_active_high();
    join_none

    //#(SYSCLK_PERIOD_NS*150000);

    generate_usersignal_write();

    #(SYSCLK_PERIOD_NS*100);

   
  end

reg flag = 0;

  always @(posedge sys_clk_i ) begin
     if (init_calib_complete == 1 && flag == 0) begin
        flag <= 1;
        $display("STATUS REPORT: CALIB INIT done");
        #(SYSCLK_PERIOD_PS*10000);
        write_ddr3( 28'b0000000000000000000000011000, 128'habababab);
        write_ddr3( 28'b0000000000000000000000100000, 128'hbbbbccccdddd);
         #(SYSCLK_PERIOD_PS*10000);
        write_ddr3( 28'b0000000000000000000011110000, 128'habcdabcdabcdabcdabcd);
         #(SYSCLK_PERIOD_PS*10000);
         read_ddr3(28'b0000000000000000000011110000);
         #(SYSCLK_PERIOD_PS*100);
         read_ddr3(28'b0000000000000000000000011000);
        //generate_usersignal_write();
        #(SYSCLK_PERIOD_PS*10000);
        $finish;
    end  
  end

endmodule
