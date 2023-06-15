module DRAM_CONTROLLER #(
    parameter DDR3_DQ_WIDTH = 16,
    parameter DDR3_DQS_WIDTH = 2,   // each byte data with one DQS line. 
    parameter DDR3_ADDR_WIDTH = 14, // MEMORY SIZE = 2^DDR3_ADDR_WIDTH
    parameter DDR3_BA_WIDTH = 3, // BANK NUM = 2^DDR3_BA_WIDTH
    parameter DDR3_DM_WIDTH = 2,
    parameter APP_ADDR_WIDTH = 28, // rank, bank, column, row
    parameter APP_CMD_WIDTH = 3,
    parameter APP_DATA_WIDTH = 128,
    parameter APP_MASK_WIDTH = 16
) 
(
    input wire sys_clk,
    input wire ref_clk,
    input wire sys_rst, // active high

    //DDR3 physical interface. these pins should be external pin
        //Data lane
        inout wire [DDR3_DQ_WIDTH-1:0] ddr3_dq,         // data bus
        inout wire [DDR3_DQS_WIDTH-1:0] ddr3_dqs_n,     // each byte 
        inout wire [DDR3_DQS_WIDTH-1:0] ddr3_dqs_p,
        //Address and Command Lane
        output wire [DDR3_ADDR_WIDTH-1:0] ddr3_addr,
        output wire [DDR3_ADDR_WIDTH-1:0] ddr3_ba,
        output wire ddr3_ras_n,
        output wire ddr3_cas_n,
        output wire ddr3_we_n,
        output wire ddr3_reset_n,
        output wire [0:0]   ddr3_ck_p,
        output wire [0:0]   ddr3_ck_n,
        output wire [0:0]   ddr3_cke,
        output wire [0:0]   ddr3_cs_n,
        output wire [DDR3_DM_WIDTH-1 : 0] ddr3_dm,
        output wire [0:0]   ddr3_odt,

    output wire o_clk,
    output wire o_rst,

    input wire i_rd_en,
    input wire i_wr_en,
    input wire [APP_ADDR_WIDTH-1:0] i_addr,
    input wire [APP_DATA_WIDTH-1:0] i_data,
    input wire [APP_MASK_WIDTH-1:0] i_mask,
    output wire o_init_calib_complete,
    output wire [APP_DATA_WIDTH-1:0] o_data,
    output wire  o_data_valid,
    output wire  o_ready,
    output wire  o_wdf_ready);

    wire [APP_ADDR_WIDTH-1:0] app_addr;
    wire [APP_CMD_WIDTH-1:0] app_cmd;
    wire app_en;
    wire [APP_DATA_WIDTH-1:0] app_wdf_data;
    wire app_wdf_wren;
    wire [APP_MASK_WIDTH-1:0] app_wdf_data;
    wire [APP_DATA_WIDTH-1:0] app_rd_data;
    wire app_rd_data_valid;
    wire app_rdy;
    wire app_wdf_rdy;

    wire    clk;
    wire    rst;

    wire        init_calib_complete;

    assign o_clk=clk;
    assign o_rst = rst;

    // Buffer module between MIG and PL. 
    MIGUI #(
        .APP_ADDR_WIDTH(APP_ADDR_WIDTH),
        .APP_CMD_WIDTH(APP_CMD_WIDTH),
        .APP_DATA_WIDTH(APP_DATA_WIDTH),
        .APP_MASK_WIDTH(APP_MASK_WIDTH)
    )mig_ui(
        .clk(clk),
        .i_rst(rst),
        
        .i_rd_en(i_rd_en),
        .i_wr_en(i_wr_en),
        .i_addr(i_addr),
        .i_data(i_data),
        .i_mask(i_mask),
        .o_data(o_data),
        .o_data_valid(o_data_valid),
        .o_ready(o_ready),
        .o_wdf_ready(o_wdf_ready),
        .o_init_calib_complete(o_init_calib_complete),

        .app_addr(app_addr),
        .app_cmd(app_cmd),
        .app_en(app_en),
        .app_wdf_data(app_wdf_data),
        .app_rd_data_valid(app_rd_data_valid),
        .i_init_calib_complete(init_calib_complete)
    );

    // MIG (module geenrated by Vivado)
    mig_7series_0 mig(
    //DDR3 physical interface. these pins should be external pin
        //Data lane
        .ddr3_dq           (ddr3_dq),
        .ddr3_dqs_n        (ddr3_dqs_n),
        .ddr3_dqs_p        (ddr3_dqs_p),

         //Address and Command Lane
        .ddr3_addr         (ddr3_addr),
        .ddr3_ba           (ddr3_ba),
        .ddr3_cas_n        (ddr3_cas_n),
        .ddr3_ck_n         (ddr3_ck_n),
        .ddr3_ck_p         (ddr3_ck_p),
        .ddr3_cke          (ddr3_cke),
        .ddr3_ras_n        (ddr3_ras_n),
        .ddr3_we_n         (ddr3_we_n),
        .ddr3_reset_n      (ddr3_reset_n),
        .ddr3_cs_n         (ddr3_cs_n),
        .ddr3_dm           (ddr3_dm),
        .ddr3_odt          (ddr3_odt),

    // PL interface
        .app_addr               (app_addr),
        .app_cmd                (app_cmd),
        .app_en                 (app_en),
        .app_wdf_data           (app_wdf_data),
        .app_wdf_end            (app_wdf_end),
        .app_wdf_wren           (app_wdf_wren),
        .app_wdf_mask           (app_wdf_mask),
        .app_wdf_data           (app_wdf_data),
        .app_rd_data            (app_rd_data),
        .app_rd_data_valid      (app_rd_data_valid),
        .app_rd_data_end        (),
        .app_rdy                (app_rdy),
        .app_wdf_rdy            (app_wdf_rdy),
        .app_wdf_rdy            (app_wdf_rdy),
        .app_sr_req             (1'b0),
        .app_ref_req            (1'b0),
        .app_zq_req             (1'b0),
        .app_sr_active          (),
        .app_ref_ack            (),
        .app_zq_ack             (),
        .ui_clk                 (clk),
        .ui_clk_sync_rst        (rst),
        .init_calib_complete    (init_calib_complete),
        .device_temp            (),

        .sys_clk_i              (sys_clk),
        .clk_ref_i              (ref_clk),
        .sys_rst                (sys_rst));

    
endmodule