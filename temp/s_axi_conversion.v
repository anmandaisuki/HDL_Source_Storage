module S_AXI_CONVERSION #(
    parameter WDATA_WIDTH   = 32   ,
    parameter RDATA_WIDTH   = 32   ,
    parameter ADDR_WIDTH    = 8    ,   // ADDR_DEPTH = 2**ADDR_WIDTH
    parameter BURST_LENGTH  = 100  ,   // 2**8 = 256 is Max burst length
    parameter ID_LENGTH     = 4    ,
    parameter BUFF_DEPTH    = 10   ,
) (
    // AXI Interface

        input wire S_AXI_ACLK,
        input wire S_AXI_ARESETN,
        
        //AR adress read channel
        input  wire [ADDR_WIDTH-1:0]     S_AXI_ARADDR , // address(each byte)
        input  wire                      S_AXI_ARVALID,
        output wire                      S_AXI_ARREADY, 

        input wire [7:0]        S_AXI_ARLEN   , // burst length. 1-255. Actual Num is + 1. ex) S_AXI_ARLEN = 20 : 21 data is tranported.  
        input wire [2:0]        S_AXI_ARSIZE  , // data length. 000:1byte, 001:2byte, 010:4byte, 011:8byte, 100:16byte, 101:32byte, 110:64byte, 111:128byte.  => Mostly 4byte(32bit) which is the same as bus width.
        input wire [1:0]        S_AXI_ARBURST , // burst type. 00:Fixed address, 01:Incriment address, 10:WRAP, 11:Reserved.

        // input wire [1:0]        S_AXI_ARLOCK  , // lock
        // input wire [3:0]        S_AXI_ARCACHE , // cache
        // input wire [2:0]        S_AXI_ARPROT  , // access limitation for address
        input wire [ID_LENGTH-1:0]              S_AXI_ARID    , // ID for out of order transaction
        // input wire [3:0]        S_AXI_ARQOS   , // speed limitation
        // input wire [3:0]        S_AXI_ARREGION, // 
        // input wire              S_AXI_ARUSER  , // USER DEFINITON


        //R data read channel
        output wire [RDATA_WIDTH-1:0]   S_AXI_RDATA ,
        output wire                     S_AXI_RVALID,
        input wire                      S_AXI_RREADY,

        output wire                     S_AXI_RLAST , // last data
        // output wire [1:0]        S_AXI_RRESP , // Response: 00:OKAY, 01:EXOKEY, 10:SLVERR, 11:DECERR
        output wire [ID_LENGTH-1:0]     S_AXI_RID   , // ID for out of order transaction
        // output wire             S_AXI_RUSER , // USER DEFINITON


        //AW adress write channel
        input wire [ADDR_WIDTH-1:0]     S_AXI_AWADDR ,
        input wire                      S_AXI_AWVALID,
        output wire                     S_AXI_AWREADY,

        input wire [7:0]                S_AXI_AWLEN   , // burst length 
        input wire [2:0]                S_AXI_AWSIZE  , // data length 
        input wire [1:0]                S_AXI_AWBURST , // burst type

        // input wire [1:0]              S_AXI_AWLOCK  , // lock
        // input wire [3:0]              S_AXI_AWCACHE , // cache
        // input wire [2:0]              S_AXI_AWPROT  , // access limitation for address
        // input wire                    S_AXI_AWID    , // ID for out of order transaction
        // input wire [3:0]              S_AXI_AWQOS   , // speed limitation
        // input wire [3:0]              S_AXI_AWREGION, // speed limitation
        // input wire                    S_AXI_AWUSER  , // USER DEFINITON

        

        // W data write channel
        input  wire [WDATA_WIDTH-1:0]       S_AXI_WDATA ,
        input  wire                         S_AXI_WVALID,
        output wire                         S_AXI_WREADY,
        input  wire                         S_AXI_WLAST ,
        // input wire [WDATA_WIDTH/8-1:0]       S_AXI_WSTRB,
        // input wire                           S_AXI_WUSER,

        // B (Responce for W channel)
        output wire                 S_AXI_BVALID,
        input  wire                 S_AXI_BREADY,
        output wire [1:0]           S_AXI_BRESP ,   //00:OKAY, 01:EXOKEY, 10:SLVERR, 11:DECERR
        // output wire S_AXI_BID        ,
        // output wire S_AXI_BUSER      ,

    // User Interface (Modify by yourself depends on the application.)
        output wire [ADDR_WIDTH-1:0]        ADDRESS_FROM_AXI,
        input  wire [RDATA_WIDTH-1:0]       DATA_TO_AXI     ,
        input  wire                         DATA_VALID      ,

        //Variable Interface


);

localparam  OK = 2'b00 ; // RESP signal. 
localparam BURSTMODE_WIDTH = 2;
localparam DATASIZE_WIDTH = 3;
localparam DATALEN_WIDTH = 8;

reg[ID_LENGTH + DATALEN_WIDTH + DATASIZE_WIDTH + BURSTMODE_WIDTH + ADDR_WIDTH-1:0]   ADDR_BUF [BUFF_DEPTH-1:0]; // store Adress and other info. {ID, Data Len, Data Size, Burst mode, ADDR }
reg [$clog2(BUFF_DEPTH+1)-1:0]  buf_cnt;

// AR SIGNAL PROCESS
    reg arready;
    assign S_AXI_ARREADY = arready;

    reg araddr;
    assign ADDRESS_FROM_AXI = araddr;

    //reg rvalid_flag; // This falg is H after detecting ARVALID and ARREAD turn H and AR transaction completed.  

    always @(posedge S_AXI_ACLK ) begin
        if(!S_AXI_ARESETN) begin
            arready <= 0;
            buf_cnt <= 0;
        end else begin
            if(!buf_cnt < BUFF_DEPTH) begin // if ADDR_BUF is not full. 
                arready <= 1;
                if(S_AXI_ARVALID) begin
                    ADDR_BUF[buf_cnt] <= {S_AXI_RID, S_AXI_ARLEN, S_AXI_ARSIZE, S_AXI_ARBURST, S_AXI_ARADDR};
                    buf_cnt           <= buf_cnt + 1;
                end
            end else begin
                arready <= 0;
            end
        end
    end

//R SIGNAL PROCESS
    reg [RDATA_WIDTH-1:0]   rdata;
    assign S_AXI_RDATA = rdata;

    reg rvalid;
    assign S_AXI_RVALID = rvalid;

    reg [ADDR_WIDTH-1:0] addr_from_axi;
    assign ADDRESS_FROM_AXI = addr_from_axi;

    reg [1:0] rresp;
    assign S_AXI_RRESP = rresp;

    reg [ID_LENGTH-1:0] rid;
    assign S_AXI_RID = rid;

    reg [ADDR_WIDTH-1:0] addr_incr_for_burst;


    always @(posedge S_AXI_ACLK ) begin

        if(!S_AXI_ACLK) begin
            rdata               <= 0;  
            buf_cnt             <= 0;
            addr_incr_for_burst <= 0;      
        end else begin

            addr_from_axi <= [ADDR_WIDTH-1:0]ADDR_BUF[buf_cnt-1] + addr_incr_for_burst;

            if(DATA_VALID && (buf_cnt!=0))begin // output to S_AXI_RDATA if DATA_VALID is H and buf_cnt is not 0. 
                rdata       <=  DATA_TO_AXI;
                rid         <=  [ID_LENGTH + DATALEN_WIDTH + DATASIZE_WIDTH + BURSTMODE_WIDTH + ADDR_WIDTH-1: DATALEN_WIDTH + DATASIZE_WIDTH + BURSTMODE_WIDTH + ADDR_WIDTH] ADDR_BUF[buf_cnt-1]; // Extract ID data
                rresp       <=  OK;
                rvalid      <=  1;

                if(S_AXI_RREADY)begin // Read Data is successfully transported.
                    if(addr_incr_for_burst + 1 > [ DATALEN_WIDTH + DATASIZE_WIDTH + BURSTMODE_WIDTH + ADDR_WIDTH - 1:DATASIZE_WIDTH + BURSTMODE_WIDTH + ADDR_WIDTH]ADDR_BUF[buf_cnt - 1])  begin
                        buf_cnt             <= buf_cnt - 1;
                        addr_incr_for_burst <= 0;
                    end else begin   // If burst length is also completed. 
                        addr_incr_for_burst <= addr_incr_for_burst + 1;
                    end
                end 
            end else begin
                rvalid <= 0;
            end

        end
    end

 // User Interface (Modify by yourself depends on the application.)
    





    
endmodule