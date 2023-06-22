// Serialize
// ex) DATA_WIDTH = 128, DIVIDE_NUM = 4, 128bit(1 clock) -> 32bit(4clock)
// ex) DATA_WIDTH = 8, DIVIDE_NUM = 8, 8bit(1 clock) -> 1bit (8 clock) 
module SERIALIZE_CIRCUIT #(
    parameter DATA_WIDTH = 128,
    parameter DIVIDE_NUM = 4
)(
    input wire                                      i_clk_para, // Parallel side clk.
    input wire                                      i_clk_out, // Serial side clk. This clk should be a little behind of i_clk_para. This clk frequency also should be PARA_NUM*i_clk_para. 
    input wire [DATA_WIDTH-1:0]                      i_data,
    output wire[DATA_WIDTH/DIVIDE_NUM-1:0]          o_data,
    output wire                                     o_clk);

localparam ADDR_WIDTH = $clog2(DIVIDE_NUM+1);
localparam DATAOUT_WIDTH = DATA_WIDTH/DIVIDE_NUM ;

//reg[DATA_WIDTH-1:0]             tmp_data;
reg[DATA_WIDTH/DIVIDE_NUM-1:0]  tmp_data[DIVIDE_NUM-1:0];
reg[DATA_WIDTH/DIVIDE_NUM-1:0]  data_out;
reg[ADDR_WIDTH-1:0]             data_cnt;

assign o_data = data_out;
assign o_clk = i_clk_out;

integer integer_i;
reg[DATA_WIDTH-(DATA_WIDTH/DIVIDE_NUM):0] dummy_reg;


always @(posedge i_clk_para ) begin
    tmp_data[0] <= i_data[31:0];
    tmp_data[1] <= i_data[63:32];
    for (integer_i = 0 ; integer_i < DIVIDE_NUM ; integer_i = integer_i + 1 ) begin
         {dummy_reg,tmp_data[integer_i]} <= (i_data>>(DATA_WIDTH/DIVIDE_NUM)*integer_i);
    end

end

always @(posedge i_clk_out ) begin
    if(data_cnt == DIVIDE_NUM-1) begin 
        data_cnt <= 0;
        data_out <= tmp_data[data_cnt];
    end else begin
        data_cnt <= data_cnt + 1;
        data_out <= tmp_data[data_cnt];
    end
end

endmodule