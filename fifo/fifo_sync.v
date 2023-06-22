module FIFO_SYNC #(
    parameter DATA_WIDTH = 512,
    parameter ADDR_WIDTH = 8 // FIFO_DEPTH = 2^ADDR_WIDTH
) (
     input  wire                    clk,
     input  wire                    i_rst,
     input  wire                    i_wen,
     input  wire [DATA_WIDTH-1 : 0] i_data,
     input  wire                    i_ren,
     output wire [DATA_WIDTH-1 : 0] o_data,
     output wire                    o_empty,
     output wire                    o_full
);

reg[DATA_WIDTH-1:0] FIFO [2**ADDR_WIDTH-1:0];

reg[ADDR_WIDTH:0] r_pnt; // read pointer(ring buffer)
reg[ADDR_WIDTH:0] w_pnt; // write pointer(ring buffer)

assign o_empty = (w_pnt == r_pnt);
assign o_full = (w_pnt[ADDR_WIDTH]!= r_pnt[ADDR_WIDTH] && w_pnt[ADDR_WIDTH-1:0]==r_pnt[ADDR_WIDTH-1:0]);

reg [DATA_WIDTH-1:0] read_data_from_fifo;
assign o_data = read_data_from_fifo;

always @(posedge clk ) begin
    if (i_rst) begin
        r_pnt <= 0;
        w_pnt <= 0;
    end else begin
        if(i_wen)begin
            w_pnt <= w_pnt + 1;
            FIFO[w_pnt[ADDR_WIDTH-1:0]] <= i_data;
        end
        if (i_ren) begin
            r_pnt <= r_pnt + 1;
            read_data_from_fifo <= FIFO[r_pnt[ADDR_WIDTH-1:0]];
        end
    end
end
    
endmodule