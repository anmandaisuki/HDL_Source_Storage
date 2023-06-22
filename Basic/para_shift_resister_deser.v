// Deserialize
// ex) 8bit*16clock -> 128bit*1clock
module PARA_SHIFT_RESISTER_DESER #(
    parameter DATA_WIDTH = 8,
    parameter SHIFT_NUM  = 16 
)(
    input wire i_clk,
    input wire [DATA_WIDTH-1:0] i_data,
    output wire [DATA_WIDTH*SHIFT_NUM-1:0] o_data,
    output wire o_clk
);

genvar genvar_i;

generate
    for(genvar_i=0; genvar_i < DATA_WIDTH; genvar_i = genvar_i + 1) begin

        SHIFT_RESISTER_DESER #(
            .SHIFT_NUM(SHIFT_NUM)
        )shift_resister_deser(
            .i_clk(i_clk),
            .i_data(i_data[genvar_i]),
            .o_data(o_data[genvar_i*DATA_WIDTH]),
            .o_clk(o_clk)
        );
    end
endgenerate


endmodule