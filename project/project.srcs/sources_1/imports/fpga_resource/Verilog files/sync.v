`timescale 1ns / 1ps

module sync(
input wire in,
input wire clk,
output wire out);

reg pipeline[2:0];

always@(posedge clk) begin
    pipeline[0]<=in;
    pipeline[1]<=pipeline[0];
    pipeline[2]<=pipeline[1];
end

assign out=pipeline[2];

endmodule
