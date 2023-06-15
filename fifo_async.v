module fifo_async #(
    parameter DATA_WIDTH = 512,
    parameter ADDR_WIDTH = 8,   // FIFO_DEPTH = 2^ADDR_WIDTH
) (
    // Write side (Input Data)
    input wire write_clk,
    input wire write_rst,
    input wire write_en,

    input wire [DATA_WIDTH-1:0] data_in,
    output wire empty,

    // Read side (Output Data)
    input wire read_clk,
    input wire read_rst,
    input wire read_en,

    output wire [DATA_WIDTH-1:0] data_out,
    output wire full,
);

reg [DATA_WIDTH-1 : 0] async_fifo[(2**ADDR_WIDTH)-1 : 0];
reg [ADDR_WIDTH:0] w_addr; // actual current address to write data
reg [ADDR_WIDTH:0] r_addr; // actual current address to read data

reg [ADDR_WIDTH:0] w_addr_gray_1; // single flip flopped write address possibly has Meta status. Buffer register. 
reg [ADDR_WIDTH:0] r_addr_gray_1; // Single flip flopped read address possibly has Meta status. Buffer register. 

reg [ADDR_WIDTH:0] w_addr_gray_2; // double flip flopped write address converted to binary address
reg [ADDR_WIDTH:0] r_addr_gray_2; // double flip flopped read address converted to binary address

wire [DATA_WIDTH-1:0] data;

wire [ADDR_WIDTH:0] w_addr_gray; // current write address (gray code expression) connected from w_addr reg.
wire [ADDR_WIDTH:0] r_addr_gray; //current read address (gray code expression) connected from r_addr reg.

wire [ADDR_WIDTH:0] w_addr2; // write address for read side. 2 clock behind connected from w_addr_gray_2 reg.
wire [ADDR_WIDTH:0] r_addr2; // read address for write side. 2 clock behind connected from r_addr_gray_2 reg.

genvar genvar_i;

assign data_out = data;
assign empty = (r_addr == w_addr2); // all data is already read. 
assign full = (w_addr[ADDR_WIDTH]!=r_addr2[ADDR_WIDTH]) && (w_addr[ADDR_WIDTH-1:0]==r_addr2[ADDR_WIDTH-1:0]);

//generate gray code from binary address
assign r_addr_gray = r_addr[ADDR_WIDTH:0]^{1'b0, r_addr[ADDR_WIDTH-1:0]};
assign w_addr_gray = w_addr[ADDR_WIDTH:0]^{1'b0, w_addr[ADDR_WIDTH-1:0]};

// generate binary address from gray code. This address is generated from double flip floped data in order to generate empty/full flag.
generate
    for(genvar_i=0; genvar_i < ADDR_WIDTH; genvar_i = genvar_i + 1) begin
        assign r_addr2[genvar_i] = ^r_addr_gray_2[ADDR_WIDTH:genvar_i];
        assign w_addr2[genvar_i] = ^w_addr_gray_2[ADDR_WIDTH:genvar_i];
    end
endgenerate

// double flip flop to get rid of Meta Status. Read side address is tranferred to Write side. 
always @(posedge write_clk) begin
    if (write_rst) begin
        r_addr_gray_1<=0;
        r_addr_gray_2<=0;
    end else begin
        r_addr_gray_1 <= r_addr_gray;
        r_addr_gray_2 <= r_addr_gray_1;
    end
end

// double flip flop to get rid of Meta Status. Write side address is tranferred to Read side. 
always @(posedge read_clk) begin
    if (read_rst) begin
        w_addr_gray_1<=0;
        w_addr_gray_2<=0;
    end else begin
        w_addr_gray_1 <= w_addr_gray;
        w_addr_gray_2 <= w_addr_gray_1;
    end
end

// Read data
assign data = async_fifo[r_addr[ADDR_WIDTH-1 : 0]];
always @(posedge read_clk ) begin
    if (read_rst) begin
        r_addr <= 0;
    end else if (read_en) begin
        r_addr <= r_addr + 1;
    end
end

//Write data
always @(posedge write_clk ) begin
    if (write_rst) begin
        w_addr <= 0;        
    end else if (write_en) begin
        async_fifo[w_addr[ADDR_WIDTH-1:0]] <= data;
        w_addr <= w_addr + 1;
    end
    
end

    
endmodule