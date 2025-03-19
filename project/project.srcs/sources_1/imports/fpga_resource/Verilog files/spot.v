module spot (
input wire clk,
input wire spot_in,
output wire spot_out);

reg D;
always @(posedge clk) begin
    D <= spot_in;
end

assign spot_out = (~D) & spot_in;

endmodule