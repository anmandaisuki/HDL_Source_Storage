// Discription
// Normal Sync FIFO
// Write counter and Read counter Gap is maintained circularly. 
// Counter incrimentation 
//ex) 4bit 
//  1101 -> 1110 -> 1111 -> 0000 -> 0001      // counter is automatically restarted with incriment. Circular address. 
//  0001 - 1110 = 0011    // The gap between write counter and read counter is sustained even after counter restart. 

module fifo_sync #(
    parameter ADDRESS_WIDTH = 8,
    parameter  DATA_WIDTH = 8,
    parameter FIFO_DEPTH = (1 << ADDRESS_WIDTH),
    parameter THRESHOLD_WRITE = FIFO_DEPTH * (3/4),
    parameter THRESHOLD_READ = FIFO_DEPTH * (1/4),

) (
    output wire wr_rdy, // not full
    output wire rd_rdy, // not empty
    input wire rd_en,
    input wire wr_en,

    input wire[DATA_WIDTH-1:0] data_in,
    output reg[DATA_WIDTH-1:0] data_out,

    input wire clk,
    input wire reset,

    output wire almost_full, // optional
    output wire almost_empty // optional 
    output wire full, // optional
    output wire empty // optional 
);

    // read/write address works circularly. No need to decriment address. 
    reg[ADDRESS_WIDTH:0] wr_ad; // 1 bit expanded to count properly
    reg[ADDRESS_WIDTH:0] rd_ad; //
    wire[ADDRESS_WIDTH:0] ad_df; // write address - read address. If ad_df[ADDRESS_WIDTH] = 1, ad_df is out of range. 

    // As long as ad_df is in the range of 8bit, rd_ad and wr_ad works properly. 
    assign ad_df = wr_ad-rd_ad; // "ad_df = 0" means 'empty'. ad_df[ADDRESS_WIDTH]=1 means 'full'.

    assign wr_rdy = ~full & ~ad_df[ADDRESS_WIDTH]; // not full && ad_df is proper gap
    assign rd_rdy = ~empty & ~ad_df[ADDRESS_WIDTH]; // not empty &&  ad_df is proper gap


    // full and empty flag
    assign full = ad_df[ADDRESS_WIDTH];
    assign empty = (ad_df == 0);
    assign almost_full =(ad_df[ADDRESS_WIDTH-1:0]>= THRESHOLD_WRITE); // If FIFO is stored more than threshold, write flag is L 
    assign almost_empty=(ad_df[ADDRESS_WIDTH-1:0]<= THRESHOLD_READ);  // If FIFO doesnt have as much data as threshold, read flag is L.

    reg [DATA_WIDTH:0] FIFO [0:FIFO_DEPTH-1];

    // Read address incriment
    always @(posedge clk ) begin
        if (reset) rd_ad <= 0;
        else if(rd_en) rd_ad <= rd_ad + 1'b1;         
    end

    // Write address incriment
    always @(posedge clk ) begin
        if (reset) wr_ad <= 0;
        else if(wr_en) wr_ad <= wr_ad + 1'b1;         
    end

    // Write process
    always @(posedge clk ) begin
        if (wr_en) FIFO[wr_ad[ADDRESS_WIDTH-1:0]] <= data_in;
    end

    //Read process
    always @(posedge clk ) begin
        if (rd_en) data_out <= FIFO[rd_ad[ADDRESS_WIDTH-1:0]];
    end
    
endmodule