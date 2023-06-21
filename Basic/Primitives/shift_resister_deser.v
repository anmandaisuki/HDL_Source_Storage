// Deserialize
module SHIFT_RESISTER_DESER #(
    parameter SHIFT_NUM = 4
)(
    input wire i_clk,
    input wire i_data,
    output wire[SHIFT_NUM-1:0] o_data,
    output wire o_clk
);

reg [SHIFT_NUM-1:0] shift_reg;
reg clk_out;
assign o_clk = clk_out;

localparam ADDR_WIDTH = $clog2(SHIFT_NUM+1);
reg [ADDR_WIDTH-1:0] shift_num = 0;

always @(posedge i_clk ) begin
    if (shift_num == SHIFT_NUM - 1) begin
        shift_num <= 0;
        shift_reg[shift_num] <= i_data;
    end else begin
        shift_num <= shift_num + 1;
        shift_reg [shift_num] <= i_data;
    end
end

// generate o_clk
always @(posedge i_clk) begin
    if(shift_num == 0) clk_out <= 1;   
    else clk_out <= 0;   
end

endmodule