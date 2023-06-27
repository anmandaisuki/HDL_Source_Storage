module ADC_IN_AXI_OUT_DRAM_INTERFACE #(
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

    parameter AXI_DATA_WIDTH    = 32 ,
    parameter AXI_ADDR_WIDTH    = 16 ,
    parameter AXI_ARSIZE        = 32 ,
    parameter AXI_ID_LENGTH     = 4  
) (
        input wire sys_clk, // clk for MIG input to generate MIG freq. Refer MIG GUI tool 
        input wire ref_clk, // clk for MIG reference. Mostly 200MHz. Refer MIG GUI tool
        input wire sys_rst, // active-high

    //DDR3 physical interface. these pins should be external pin
        //Data lane
        inout wire[DDR3_DQ_WIDTH-1:0]      ddr3_dq     ,// data bus
        inout wire[DDR3_DQS_WIDTH-1:0]     ddr3_dqs_n  ,// each byte 
        inout wire[DDR3_DQS_WIDTH-1:0]     ddr3_dqs_p  ,
        //Address and Command Lane
        output wire[DDR3_ADDR_WIDTH-1:0]   ddr3_addr   ,
        output wire[DDR3_ADDR_WIDTH-1:0]   ddr3_ba     ,
        output wire                        ddr3_ras_n  ,
        output wire                        ddr3_cas_n  ,
        output wire                        ddr3_we_n   ,
        output wire                        ddr3_reset_n,
        output wire[0:0]                   ddr3_ck_p   ,
        output wire[0:0]                   ddr3_ck_n   ,
        output wire[0:0]                   ddr3_cke    ,
        output wire[0:0]                   ddr3_cs_n   ,
        output wire[DDR3_DM_WIDTH-1 : 0]   ddr3_dm     ,
        output wire[0:0]                   ddr3_odt    ,

    // AXI read interface
        input wire                       S_AXI_ACLK   ,
        input wire                       S_AXI_ARESETN,
        //AR adress read channel
        input  wire[AXI_ADDR_WIDTH-1:0]  S_AXI_ARADDR , // address(each byte)
        input  wire                      S_AXI_ARVALID,
        output wire                      S_AXI_ARREADY, 
        input  wire[7:0]                 S_AXI_ARLEN  , // burst length. 1-255. Actual Num is + 1. ex) S_AXI_ARLEN = 20 : 21 data is tranported.  
        input  wire[2:0]                 S_AXI_ARSIZE , // data length. 000:1byte, 001:2byte, 010:4byte, 011:8byte, 100:16byte, 101:32byte, 110:64byte, 111:128byte.  => Mostly 4byte(32bit) which is the same as bus width.
        input  wire[1:0]                 S_AXI_ARBURST, // burst type. 00:Fixed address, 01:Incriment address, 10:WRAP, 11:Reserved.
        input  wire[AXI_ID_LENGTH-1:0]   S_AXI_ARID   , // ID for out of order transaction
        //R data read channel
        output wire[AXI_DATA_WIDTH-1:0]   S_AXI_RDATA ,
        output wire                       S_AXI_RVALID,
        input  wire                       S_AXI_RREADY,
        output wire                       S_AXI_RLAST , // last data
        output wire[AXI_ID_LENGTH-1:0]    S_AXI_RID   , // ID for out of order transaction
        //AW adress write channel
        input  wire[AXI_ADDR_WIDTH-1:0]  S_AXI_AWADDR ,
        input  wire                      S_AXI_AWVALID,
        output wire                      S_AXI_AWREADY,
        input  wire[7:0]                 S_AXI_AWLEN  , // burst length 
        input  wire[2:0]                 S_AXI_AWSIZE , // data length 
        input  wire[1:0]                 S_AXI_AWBRST , // burst type
        // W data write channel
        input  wire[AXI_DATA_WIDTH-1:0]   S_AXI_WDATA ,
        input  wire                       S_AXI_WVALID,
        output wire                       S_AXI_WREADY,
        input  wire                       S_AXI_WLAST ,
        // B (Responce for W channel)
        output wire                       S_AXI_BVALID,
        input  wire                       S_AXI_BREADY,
        output wire[1:0]                  S_AXI_BRESP ,   //00:OKAY, 01:EXOKEY, 10:SLVERR, 11:DECERR

    // ADC write interface
    // Physical and PL interface
        output wire                        o_adc_clk_n, 
        output wire                        o_adc_clk_p, 
        input  wire                        i_adc_clk_n, 
        input  wire                        i_adc_clk_p, 
        input  wire[ADC_DATA_WIDTH-1:0]    i_adc_data ,
        input  wire                        i_adc_data_en
    );

    // localparam
        localparam DRAM_READ_FIFO_ADDR_WIDTH = 3;
        localparam DRAM_READ_FIFO_DEPTH      = 2**DRAM_READ_FIFO_ADDR_WIDTH ;
    //MIG wire
        wire mig_ui_clk;
        wire mig_ui_rst;
        wire rst;
        wire dram_init_calib_complete;
        wire dram_ren;
        wire dram_wen;
        wire[APP_ADDR_WIDTH-2:0] dram_addr;
        wire[APP_DATA_WIDTH-1:0] dram_din;
        wire[APP_MASK_WIDTH-1:0] dram_mask;
        wire[APP_DATA_WIDTH-1:0] dram_dout;
        wire dram_dout_valid;
        wire dram_ready;
        wire dram_wdf_ready;
    // fifo-async2 wire
        wire wen_afifo2;
        wire[APP_DATA_WIDTH-1:0] din_afifo2;
        wire ren_afifo2;
        wire[APP_DATA_WIDTH-1:0] dout_afifo2;
        wire empty_afifo2;
        wire full_afifo2;
    // fifo_sync wire
        wire wen_sfifo;
        wire[APP_DATA_WIDTH-1:0] din_sfifo;
        wire ren_sfifo;
        wire[APP_DATA_WIDTH-1:0] dout_sfifo;
        wire empty_sfifo;
    // fifo-async1 wire
        wire wen_afifo1;
        wire [APP_DATA_WIDTH-1:0] din_afifo1;
        wire ren_afifo1;
        wire [APP_DATA_WIDTH-1:0] dout_afifo1;
        wire empty_afifo1;
        wire full_afifo1;
        wire [APP_DATA_WIDTH-1:0] dout_afifo1_adc_data;
    // clock and mig initializatoin check
        wire locked_a ;
        wire locked_b ;
        wire rst_async;
        reg  rst_sync1;
        reg  rst_sync2;

    reg [DRAM_READ_FIFO_ADDR_WIDTH:0] rreq_count;
    reg [DRAM_READ_FIFO_ADDR_WIDTH:0] rdat_count;
    
    // DRAM >> User Interface(AXI) Read process
        integer i;
        localparam mig_data_divide_num = $clog2((APP_DATA_WIDTH/AXI_DATA_WIDTH)+1);
        wire[7:0]                               axi_burst_num    ;
        wire                                    axi_read_ready   ;
        wire                                    address_from_axi ;
        wire[APP_ADDR_WIDTH-2:0]                current_read_addr;     
        reg[APP_DATA_WIDTH-AXI_DATA_WIDTH-1:0]  dummy            ;
        reg[AXI_DATA_WIDTH-1:0]                 data_to_axi      ;
        reg                                     data_valid       ;
        reg[7:0]                                burst_cnt        ;//to count axi burst transaction
        reg[mig_data_divide_num-1:0]            data_divide_cnt  ;//to divide mig data output
        reg[AXI_DATA_WIDTH-1:0]                 tmp_data_to_axi[(APP_DATA_WIDTH/AXI_DATA_WIDTH)-1:0];
        reg[AXI_ADDR_WIDTH-1:0]                 current_burst_addr;
        reg[7:0]                                current_burst_num ;
        reg[APP_ADDR_WIDTH-2:0]                 adc_axi_addr      ;// DRAM address to write ADC data. 
    
    //ADC
        wire                                    adc_clk;                    // input clock through clock wizard or clk buffer.
        wire                                    adc_merged_clk;             // clock for deserialized data
        wire [APP_DATA_WIDTH-1:0]               adc_data_merged;            // desirialized data
        reg                                     adc_write_en;
        reg  [APP_MASK_WIDTH-1:0]               adc_merged_mask;            // Write mask when you write ADC data to DRAM. no mask is default.               

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
            default: ;
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
            default: ;
        endcase
    endgenerate
   


    // rst_async 0 at stable status.  Stable conditoin are made then one clock later, Write FIFO starts accepting data. 1 clock gap is for safety of transaction. 
    // locked = 1 (clock is stable), mig_ui_rst = 0 (mig is not reset)  
    // rst_sync2 set L after 1 clock of stable status. FIFO write buffer set after 1 clock of clock locked and mig ready. 
    assign rst_async = mig_ui_rst | (~locked_a)|(~locked_b);
    assign rst = rst_sync2;

    always @(posedge adc_merged_clk or posedge rst_async) begin
        if(rst_async) begin
            rst_sync1 <= 1'b1;
            rst_sync2 <= 1'b1;
        end else begin
            rst_sync1 <= 1'b0;
            rst_sync2 <= rst_sync1;
        end
    end

// DRAM >> User Interface(AXI) Read process
    assign wen_afifo2 = ren_sfifo;
    assign din_afifo2 = dout_sfifo;

    assign dram_wen = axi_read_ready; // When axi reads DRAM, ADC write is disabled. 
    // assign adc_axi_addr = current_burst_addr[APP_ADDR_WIDTH-2:mig_data_divide_num] << (mig_data_divide_num);
    assign current_read_addr = current_burst_addr[APP_ADDR_WIDTH-2:mig_data_divide_num] << (mig_data_divide_num);
    
       S_AXI_CONVERSION #(
                    .WDATA_WIDTH  (AXI_DATA_WIDTH)   ,
                    .RDATA_WIDTH  (AXI_DATA_WIDTH)   ,
                    .ADDR_WIDTH   (8 )               ,   // ADDR_DEPTH = 2**ADDR_WIDTH
                    .BURST_LENGTH (8 )               ,   // 2**8 = 256 is Max burst length. Burst transaction for AXI is up to 256. 
                    .ID_LENGTH    (4 )               ,
                    .BUFF_DEPTH   (10)  
        )s_axi_conversion (
    // AXI Interface
                    .S_AXI_ACLK   (S_AXI_ACLK   )      ,
                    .S_AXI_ARESETN(S_AXI_ARESETN)      ,
        
        //AR adress read channel
                    .S_AXI_ARADDR  (S_AXI_ARADDR ) , // address(each byte)
                    .S_AXI_ARVALID (S_AXI_ARVALID) ,
                    .S_AXI_ARREADY (S_AXI_ARREADY) , 
                    .S_AXI_ARLEN   (S_AXI_ARLEN   ), // burst length. 1-255. Actual Num is + 1. ex) S_AXI_ARLEN = 20 : 21 data is tranported.  
                    .S_AXI_ARSIZE  (S_AXI_ARSIZE  ), // data length. 000:1byte, 001:2byte, 010:4byte, 011:8byte, 100:16byte, 101:32byte, 110:64byte, 111:128byte.  => Mostly 4byte(32bit) which is the same as bus width.
                    .S_AXI_ARBURST (S_AXI_ARBURST ), // burst type. 00:Fixed address, 01:Incriment address, 10:WRAP, 11:Reserved.
                    .S_AXI_ARID    (S_AXI_ARID    ), // ID for out of order transaction
        //R data read channel
                    .S_AXI_RDATA (S_AXI_RDATA ),
                    .S_AXI_RVALID(S_AXI_RVALID),
                    .S_AXI_RREADY(S_AXI_RREADY),
                    .S_AXI_RLAST (S_AXI_RLAST ), // last data
                    .S_AXI_RID   (S_AXI_RID   ), // ID for out of order transaction
        //AW adress write channel
                    .S_AXI_AWADDR (S_AXI_AWADDR ),
                    .S_AXI_AWVALID(S_AXI_AWVALID),
                    .S_AXI_AWREADY(S_AXI_AWREADY),
                    .S_AXI_AWLEN  (S_AXI_AWLEN  ), // burst length 
                    .S_AXI_AWSIZE (S_AXI_AWSIZE ), // data length 
                    .S_AXI_AWBRST (S_AXI_AWBRST ), // burst type
        // W data write channel
                    .S_AXI_WDATA (S_AXI_WDATA ),
                    .S_AXI_WVALID(S_AXI_WVALID),
                    .S_AXI_WREADY(S_AXI_WREADY),
                    .S_AXI_WLAST (S_AXI_WLAST ),
        // B (Responce for W channel)
                    .S_AXI_BVALID(S_AXI_BVALID),
                    .S_AXI_BREADY(S_AXI_BREADY),
                    .S_AXI_BRESP (S_AXI_BRESP ),   //00:OKAY, 01:EXOKEY, 10:SLVERR, 11:DECERR
    // User Interface (Modify by yourself depends on the application.)
                    .ADDRESS_FROM_AXI(address_from_axi),
                    .DATA_TO_AXI     (data_to_axi     ), // 32bit, AXI bus width
                    .DATA_VALID      (data_valid      ),
                    .DATA_READY      (axi_read_ready  ), 
                    .BURST_NUM       (axi_burst_num   )
            ); // data size is 32 bit 

    always @(posedge S_AXI_ACLK) begin
        if(!S_AXI_ARESETN || !dram_init_calib_complete)begin
            data_valid        <= 0;
            data_to_axi       <= 0;
            burst_cnt         <= 0;
            data_divide_cnt   <= 0;
          
            current_burst_addr<= 0;
            current_burst_num <= 0;
            for(i = 0; i < (APP_DATA_WIDTH/AXI_DATA_WIDTH)-1; i = i+1)begin
                tmp_data_to_axi[i] <= 0;
            end
        end else begin
            adc_axi_addr <= current_read_addr;
            if(axi_read_ready && burst_cnt == 0 && !empty_afifo2)begin // axi_read_ready(ren_afifo2) is H, burst_cnt = 0 (burst starts)
                for (i = 0; i < (APP_DATA_WIDTH/AXI_DATA_WIDTH) ; i=i+1 ) begin
                    {dummy,tmp_data_to_axi[i]}<=(AXI_DATA_WIDTH*i>>dout_afifo2)     ;
                end
                data_to_axi             <= dout_afifo2[AXI_DATA_WIDTH-1:0]          ; 
                data_valid              <= 1'b1                                     ;
                burst_cnt               <= burst_cnt + AXI_DATA_WIDTH/AXI_ARSIZE    ; 
                data_divide_cnt         <= data_divide_cnt + 1                      ;
                current_burst_addr      <= address_from_axi                         ;
              
                current_burst_num       <= axi_burst_num                            ;
            end else begin
                if(axi_read_ready && !empty_afifo2)begin
                    if(0 < burst_cnt < current_burst_num - 1) begin
                        data_to_axi             <= tmp_data_to_axi[data_divide_cnt]      ;
                        data_valid              <= 1'b1                                  ;
                        if(data_divide_cnt ==(APP_DATA_WIDTH/AXI_DATA_WIDTH)-1)begin
                            data_divide_cnt     <=  0                                    ;
                            current_burst_addr  <= current_burst_addr + DDR3_BURST_LENGTH;
                        end else begin
                            data_divide_cnt     <= data_divide_cnt + 1                   ; 
                        end
                        burst_cnt               <= burst_cnt + AXI_DATA_WIDTH/AXI_ARSIZE ; 
                    end else if (burst_cnt >= axi_burst_num - 1) begin // the last data in the burst transaction. 
                        data_to_axi             <= tmp_data_to_axi[data_divide_cnt]      ;
                        data_valid              <= 1'b1                                  ;
                        burst_cnt               <= 0                                     ;
                        data_divide_cnt         <= 0                                     ;
                    end
                end else begin
                        data_valid <= 0; // the case if empty_afifo is H 
                end
            end
        end
    end

// FIFO_async between MIG clk domain and AXI clk domain
    assign ren_afifo2 = axi_read_ready;

    FIFO_ASYNC #(
        .DATA_WIDTH(APP_DATA_WIDTH),
        .ADDR_WIDTH(3)
        )afifo2 (
        .write_clk(mig_ui_clk),
        .write_rst(rst),
        .write_en(wen_afifo2),
        .data_in(din_afifo2),
        .empty(empty_afifo2),

        .read_clk(S_AXI_ACLK),
        .read_rst(mig_ui_rst),
        .read_en(ren_afifo2),
        .data_out(dout_afifo2),
        .full(full_afifo2)
        );

// DRAM Read FIFO. Buffer between async_FIFO and DRAM. 
    assign wen_sfifo = dram_dout_valid;
    assign din_sfifo = dram_dout;
    assign ren_sfifo = !empty_sfifo;

    FIFO_SYNC #(
        .DATA_WIDTH(APP_DATA_WIDTH),
        .ADDR_WIDTH(DRAM_READ_FIFO_ADDR_WIDTH)
        )sfifo (
            .clk    (mig_ui_clk ),
            .i_rst  (mig_ui_rst ),
            .i_wen  (wen_sfifo  ),
            .i_data (din_sfifo  ),
            .i_ren  (ren_sfifo  ),
            .o_data (dout_sfifo ),
            .o_empty(empty_sfifo),
            .o_full ()
        );


    assign dram_ren = (axi_read_ready  && (rreq_count < DRAM_READ_FIFO_DEPTH)&& dram_ready); 

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
    assign wen_afifo1 = i_adc_data_en;                   
    assign din_afifo1 = adc_data_merged;
    // assign ren_afifo1 = (dram_ready && dram_wdf_ready);
    assign ren_afifo1 = dram_wen;

    // ADC data allignment. ADC_DATA_WIDTH -> APP_ADDR_WIDTH alligned.
    PARA_SHIFT_RESISTER_DESER #(
        .DATA_WIDTH     (ADC_DATA_WIDTH),
        .SHIFT_NUM      (APP_ADDR_WIDTH / ADC_DATA_WIDTH)
        )para_shift (
        .i_clk(adc_clk),
        .i_data(i_adc_data),
        .o_data(adc_data_merged),
        .o_clk(adc_merged_clk)
        );

    // generate ADC address. Just incriment in ascending order
    always @(posedge adc_merged_clk) begin
        if(dram_wen) adc_axi_addr <= adc_axi_addr + DDR3_BURST_LENGTH;
    end

    FIFO_ASYNC #(
        .DATA_WIDTH( APP_DATA_WIDTH ),
        .ADDR_WIDTH(3)
        )afifo1 (
        .write_clk(adc_merged_clk),
        .write_rst(rst),
        .write_en(wen_afifo1),

        .data_in(din_afifo1), // adc_data_merged, adc_data_en, 
        .empty(empty_afifo1),

        .read_clk(mig_ui_clk),
        .read_rst(mig_ui_rst),
        .read_en(ren_afifo1),
        .data_out(dout_afifo1_adc_data),
        .full(full_afifo1)
        );
    
    assign dram_wen     = (!empty_afifo1 && wen_afifo1 && dram_ready && dram_wdf_ready);
    assign dram_addr    = adc_axi_addr;
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
        .APP_MASK_WIDTH(APP_MASK_WIDTH)
        )dram_controller (
        .sys_clk(sys_clk),
        .ref_clk(ref_clk),
        .sys_rst(sys_rst), // active high

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
        .o_wdf_ready(dram_wdf_ready)
        );
        
endmodule