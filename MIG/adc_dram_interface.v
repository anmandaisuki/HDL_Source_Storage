module ADC_IN_AXIS_OUT_DRAM_INTERFACE #(
    parameter DDR3_DQ_WIDTH     = 16 ,
    parameter DDR3_DQS_WIDTH    = 2  ,
    parameter DDR3_ADDR_WIDTH   = 14 ,
    parameter DDR3_BA_WIDTH     = 3  ,
    parameter DDR3_DM_WIDTH     = 2  ,

    parameter APP_ADDR_WIDTH    = 28 ,
    parameter APP_CMD_WIDTH     = 3  ,
    parameter APP_DATA_WIDTH    = 128, // burst length * DDR3 data_width
    parameter APP_MASK_WIDTH    = 16 ,

    parameter ADC_DATA_WIDTH    = 8  ,
    parameter ADC_CLK_WIDTH     = 1  , // 1: single_end, 2: differential
    parameter DDR3_BURST_LENGTH = 8  ,

    parameter AXIS_DATA_WIDTH   = 32 

) (
    input wire sys_clk, // clk for MIG input to generate MIG freq. Refer MIG GUI tool 
    input wire ref_clk, // clk for MIG reference. Mostly 200MHz. Refer MIG GUI tool
    input wire sys_rst, // active-high

    output wire o_adc_clk_n, 
    output wire o_adc_clk_p, 
    input wire i_adc_clk_n, 
    input wire i_adc_clk_p, 

    //DDR3 physical interface. these pins should be external pin
        //Data lane
        inout wire [DDR3_DQ_WIDTH-1:0]      ddr3_dq,         // data bus
        inout wire [DDR3_DQS_WIDTH-1:0]     ddr3_dqs_n,     // each byte 
        inout wire [DDR3_DQS_WIDTH-1:0]     ddr3_dqs_p,
        //Address and Command Lane
        output wire [DDR3_ADDR_WIDTH-1:0]   ddr3_addr,
        output wire [DDR3_ADDR_WIDTH-1:0]   ddr3_ba,
        output wire                         ddr3_ras_n,
        output wire                         ddr3_cas_n,
        output wire                         ddr3_we_n,
        output wire                         ddr3_reset_n,
        output wire [0:0]                   ddr3_ck_p,
        output wire [0:0]                   ddr3_ck_n,
        output wire [0:0]                   ddr3_cke,
        output wire [0:0]                   ddr3_cs_n,
        output wire [DDR3_DM_WIDTH-1 : 0]   ddr3_dm,
        output wire [0:0]                   ddr3_odt,


    // user design interface
    output wire                     o_clk,  // output clk from MIG. MIG freq / 4. If MIG freq = 333.33 MHz, this clk would be 83.33 MHz. app_ signal is synthesized with this clk.
    output wire                     o_rst,
        input wire [APP_ADDR_WIDTH-2:0]                i_addr,
        output wire                     o_init_calib_complete,
        output wire                                    o_busy,

        //for read signal
        input wire                                      i_ren,
        input wire                                     i_busy,
        output wire [APP_DATA_WIDTH-1:0]               o_data,
        output wire                              o_data_valid,

        // AXIS read interface
        input wire i_axis_en;   // 1: axis bus send the data. 0:  

        input wire M_AXIS_ACLK,
        input wire M_AXIS_ARESETN,

        output wire[AXIS_DATA_WIDTH-1:0]    M_AXIS_TDATA,
        output wire                         M_AXIS_TVALID,
        input  wire                         M_AXIS_TREADY,
        // output wire M_AXIS_STRB,  // not required
        output wire                         M_AXIS_TLAST, // not necessary. Need to be L?

    // ADC write interface
    // Physical and PL interface
    input wire [ADC_DATA_WIDTH-1:0]     i_adc_data,
    input wire                          i_adc_data_en);


    localparam DRAM_CMD_FIFO_DATA_WIDTH = 1 + (APP_ADDR_WIDTH - 1) + APP_DATA_WIDTH + APP_MASK_WIDTH; // {i_wen, i_addr, i_data, i_mask}

    // DRAM read data temp buffer 
    localparam DRAM_READ_FIFO_ADDR_WIDTH = 3;
    localparam DRAM_READ_FIFO_DEPTH = 2**DRAM_READ_FIFO_ADDR_WIDTH ;

    wire mig_ui_clk;
    wire mig_ui_rst;
    wire clk;
    wire rst;

    wire dram_init_calib_complete;
    wire dram_ren;
    wire dram_wen;
    wire [APP_ADDR_WIDTH-2:0] dram_addr;
    wire [APP_DATA_WIDTH-1:0] dram_din;
    wire [APP_MASK_WIDTH-1:0] dram_mask;
    wire [APP_DATA_WIDTH-1:0] dram_dout;
    wire dram_dout_valid;
    wire dram_ready;
    wire dram_wdf_ready;

    wire dout_afifo1_adc_wen;
    wire [APP_ADDR_WIDTH-2:0] dout_afifo1_addr;

    wire [APP_MASK_WIDTH-1:0] dout_afifo1_mask;

    wire wen_afifo2;
    wire [APP_DATA_WIDTH-1:0] din_afifo2;
    wire ren_afifo2;
    wire [APP_DATA_WIDTH-1:0] dout_afifo2;
    wire empty_afifo2;
    wire full_afifo2;

    wire wen_sfifo;
    wire [APP_DATA_WIDTH-1:0] din_sfifo;
    wire ren_sfifo;
    wire [APP_DATA_WIDTH-1:0] dout_sfifo;
    wire empty_sfifo;

    reg [APP_DATA_WIDTH-1:0] data1;
    reg data_valid1 = 0;
    reg [APP_DATA_WIDTH-1:0] data2;
    reg data_valid2 = 0;

    reg dram_init_calib_complete_sync1;
    reg dram_init_calib_complete_sync2;

    // clock and mig initializatoin check
    wire locked_a;
    wire locked_b;
    wire rst_async;
    reg rst_sync1;
    reg rst_sync2;

    reg [DRAM_READ_FIFO_ADDR_WIDTH:0] rreq_count;
    reg [DRAM_READ_FIFO_ADDR_WIDTH:0] rdat_count;
   
    

    // clk_wiz_0 clkgen (
    //     .clk_in1(mig_ui_clk),
    //     .reset(mig_ui_rst),
    //     .clk_out1(clk),
    //     .locked(locked)
    // );

    // generate adc_clk
    generate
        case (ADC_CLK_WIDTH)
            1: begin
                // generate clk to feed ADC from mig_ui_clk
                clk_wiz_0 clkgen_out_to_adc (
                    .clk_in1(mig_ui_clk),
                    .reset(mig_ui_rst),
                    .clk_out1(o_adc_clk_n),
                    .locked(locked_a)
                );
            end
            2: begin    // differential
                
            end
            default: 
        endcase
    endgenerate

    generate
        case (ADC_CLK_WIDTH)
            1: begin
                // phase is also need to be adjusted between i_adc_clk and o_adc_clk
                clk_wiz_0 clkgen_in_from_adc (
                    .clk_in1(i_adc_clk_n),
                    .reset(mig_ui_rst),
                    .clk_out1(adc_clk),
                    .locked(locked_b)
                );
            end
            2: begin // differential
                
            end
            default: 
        endcase
    endgenerate
   


    // rst_async 0 at stable status.  Stable conditoin made then one clock later, Write FIFO starts accepting data. 1 clock gap is for safety of transaction. 
    // locked = 1 (clock is stable), mig_ui_rst = 0 (mig is not reset)  
    // rst_sync2 set L after 1 clock of stable status. FIFO write buffer set after 1 clock of clock locked and mig ready. 
    assign rst_async = mig_ui_rst | (~locked_a)|(~locked_b);
    assign rst = rst_sync2;

    always @(posedge clk or posedge rst_async) begin
        if(rst_async) begin
            rst_sync1 <= 1'b1;
            rst_sync2 <= 1'b1;
        end else begin
            rst_sync1 <= 1'b0;
            rst_sync2 <= rst_sync1;
        end
    end

// DRAM >> User Interface 
    assign wen_afifo2 = ren_sfifo;
    assign din_afifo2 = dout_sfifo;
    // assign ren_afifo2 = (!empty_afifo2 &&  !i_busy);
    reg [AXIS_DATA_WIDTH-1:0] axis_dataout;
    
    assign M_AXIS_TDATA  = axis_dataout;
    assign M_AXIS_TVALID = !mig_ui_rst;
    assign M_AXIS_TLAST  = mig_ui_rst;
    assign ren_afifo2    = !empty_afifo2 & !mig_ui_rst & M_AXIS_TREADY & M_AXIS_ARESETN;

    always @(posedge M_AXIS_ACLK) begin
        if(!M_AXIS_ARESETN)begin
            axis_dataout <= 0;
        end else begin
            if(M_AXIS_TREADY)begin
                axis_dataout <= dout_afifo2;
            end
        end       
    end

    

    FIFO_ASYNC #(
        .DATA_WIDTH(DRAM_CMD_FIFO_DATA_WIDTH),
        .ADDR_WIDTH(3))
        afifo2 (
        .write_clk(mig_ui_clk),
        .write_rst(rst),
        .write_en(wen_afifo2),
        .data_in(din_afifo2),
        .empty(empty_afifo2),

        .read_clk(M_AXIS_ACLK),
        .read_rst(mig_ui_rst),
        .read_en(ren_afifo2),
        .data_out(dout_afifo2),
        .full(full_afifo2));

// DRAM Read FIFO. Buufer between async_FIFO and DRAM. s
    assign wen_sfifo = dram_dout_valid;
    assign din_sfifo = dram_dout;
    assign ren_sfifo = !empty_sfifo;
    // assign ren_sfifo = (!empty_sfifo && !full_afifo2);

    FIFO_SYNC #(
        .DATA_WIDTH(APP_DATA_WIDTH),
        .ADDR_WIDTH(DRAM_READ_FIFO_ADDR_WIDTH))
        sfifo (
            .clk(mig_ui_clk),
            .i_rst(mig_ui_rst),
            .i_wen(wen_sfifo),
            .i_data(din_sfifo),
            .i_ren(ren_sfifo),
            .o_data(dout_sfifo),
            .o_empty(empty_sfifo),
            .o_full());

    // assign dram_ren = (!empty_afifo1 && !dout_afifo1_adc_wen && (rreq_count < DRAM_READ_FIFO_DEPTH)&& dram_ready); 
    assign dram_ren = (i_axis_en && (rreq_count < DRAM_READ_FIFO_DEPTH)&& dram_ready); 

    always @(posedge mig_ui_clk) begin
        if(mig_ui_rst)begin
            rreq_count <=  0;
            rdat_count <= 0;
        end else begin
            if(dram_ren)begin
                rreq_count <= rreq_count + 1;
            end
            if(dram_dout_valid)begin
                rdat_count <= rdat_count + 1;
            end
            if((rdat_count == DRAM_READ_FIFO_DEPTH)&& empty_sfifo)begin
                rreq_count <= 0;
                rdat_count <= 0;
            end
        end
    end

// ADC >> DRAM Write Process
    wire                                    adc_clk;                    // input clock through clock wizard or clk buffer.
    wire                                    adc_merged_clk;             // clock for deserialized data
    wire [APP_DATA_WIDTH-1:0]               adc_data_merged;            // desirialized data
    // wire [DDR3_ADDR_WIDTH-1:0]              adc_addr_wire;
    reg  [DDR3_ADDR_WIDTH-1:0]              adc_addr;                   // DRAM address to write ADC data. 
    // wire [APP_DATA_WIDTH-1:0]               adc_merged_mask_wire;
    reg  [APP_MASK_WIDTH-1:0]               adc_merged_mask;            // Write mask when you write ADC data to DRAM. no mask is default.               

    // afifo1 connection wire 
    wire wen_afifo1;
    wire [APP_DATA_WIDTH-1:0] din_afifo1;
    wire ren_afifo1;
    wire [APP_DATA_WIDTH-1:0] dout_afifo1;
    wire empty_afifo1;
    wire full_afifo1;
    wire [APP_DATA_WIDTH-1:0] dout_afifo1_adc_data;

    assign wen_afifo1 = i_adc_data_en;                   
    assign din_afifo1 = adc_data_merged;
    // assign ren_afifo1 = (dram_ready && dram_wdf_ready);
    assign ren_afifo1 = dram_wen;

    // ADC data allignment. ADC_DATA_WIDTH -> APP_ADDR_WIDTH alligned.
    PARA_SHIFT_RESISTER_DESER #(
        .DATA_WIDTH     (ADC_DATA_WIDTH),
        .SHIFT_NUM      (APP_ADDR_WIDTH / ADC_DATA_WIDTH)) 
        para_shift (
        .i_clk(adc_clk),
        .i_data(i_adc_data),
        .o_data(adc_data_merged),
        .o_clk(adc_merged_clk));

    // generate ADC address. Just incriment in ascending order
    always @(posedge adc_merged_clk ) begin
        if(dram_wen) adc_addr <= adc_addr + DDR3_BURST_LENGTH;
    end
    
    assign dout_afifo1_addr = adc_addr; 

    FIFO_ASYNC #(
        .DATA_WIDTH( 1 + APP_DATA_WIDTH + ),
        .ADDR_WIDTH(3))
        afifo1 (
        .write_clk(adc_merged_clk),
        .write_rst(rst),
        .write_en(wen_afifo1),

        .data_in(din_afifo1), // adc_data_merged, adc_data_en, 
        .empty(empty_afifo1),

        .read_clk(mig_ui_clk),
        .read_rst(mig_ui_rst),
        .read_en(ren_afifo1),
        .data_out(dout_afifo1_adc_data),
        .full(full_afifo1));
    
    // assign {dout_afifo1_adc_wen, dout_afifo1_adc_data} = dout_afifo1; // Divide afifo1 out data 
    assign dram_wen     = (!empty_afifo1 && wen_afifo1 && dram_ready && dram_wdf_ready);
    assign dram_addr    = adc_addr;
    assign dram_din     = dout_afifo1_adc_data;
    assign dram_mask    = adc_merged_mask;


DRAM_CONTROLLER #(
        .DDR3_DQ_WIDTH(DDR3_DQ_WIDTH),
        .DDR3_DQS_WIDTH(DDR3_DQS_WIDTH),   
        .DDR3_ADDR_WIDTH(DDR3_ADDR_WIDTH),
        .DDR3_BA_WIDTH(DDR3_BA_WIDTH), 
        .DDR3_DM_WIDTH(DDR3_DM_WIDTH),
        .APP_ADDR_WIDTH(APP_ADDR_WIDTH), 
        .APP_CMD_WIDTH(APP_CMD_WIDTH),
        .APP_DATA_WIDTH(APP_DATA_WIDTH),
        .APP_MASK_WIDTH(APP_MASK_WIDTH))
    dram_controller (
        sys_clk(sys_clk),
        ref_clk(ref_clk),
        sys_rst(sys_rst), // active high

        //DDR3 physical interface. these pins should be external pin
            //Data lane
            .ddr3_dq(ddr3_dq),         // data bus
            .ddr3_dqs_n(ddr3_dqs_n),     // each byte 
            .ddr3_dqs_p(ddr3_dqs_p),
            //Address and Command Lane
            .ddr3_addr(ddr3_addr),
            .ddr3_ba(ddr3_ba),
            .ddr3_ras_n(ddr3_ras_n),
            .ddr3_cas_n(ddr3_cas_n),
            .ddr3_we_n(ddr3_we_n),
            .ddr3_reset_n(ddr3_reset_n),
            .ddr3_ck_p(ddr3_ck_p),
            .ddr3_ck_n(ddr3_ck_n),
            .ddr3_cke(ddr3_cke),
            .ddr3_cs_n(ddr3_cs_n),
            .ddr3_dm(ddr3_dm),
            .ddr3_odt(ddr3_odt),

        .o_clk(mig_ui_clk),  // output clk from MIG. MIG freq / 4. If MIG freq = 333.33 MHz, this clk would be 83.33 MHz. app_ signal is synthesized with this clk.
        .o_rst(mig_ui_rst),

        .i_rd_en(dram_ren),
        .i_wr_en(dram_wen),
        .i_addr({1'b0,dram_addr}),
        .i_data(dram_din),
        .i_mask(dram_mask),
        .o_init_calib_complete(dram_init_calib_complete),
        .o_data(dram_dout),
        .o_data_valid(dram_dout_valid),
        .o_ready(dram_ready),
        .o_wdf_ready(dram_wdf_ready));

always @(posedge clk ) begin
    data1 <= dout_afifo2;
    data_valid1 <= !empty_afifo2;
    data2 <= data1;
    data_valid2 <= data_valid1;
end

always @(posedge M_AXIS_ACLK) begin
    if(!M_AXIS_ARESETN)begin
        
    end else begin
       if(M_AXIS_TREADY) begin
            axis_dataout <= dout_afifo2;
       end 
    end
end

assign o_data = data2;
assign o_data_valid = data_valid2;
assign o_busy = (!o_init_calib_complete || full_afifo1); 
    
);
    
endmodule