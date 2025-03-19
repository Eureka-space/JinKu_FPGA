module debouncer (
input wire switchIn,
input wire clk,
input wire reset,
output wire debounceout);

reg [2:0] pipeline;
wire beat;

clockDividerHB #(.THRESHOLD(3_333_333)) beatGen (.reset(reset), .enable(1'b1), .clk(clk), .dividedClk(), .beat(beat));

always @(posedge clk) begin
    if (beat == 1'b1) begin
        pipeline[0] <= switchIn;
        pipeline[1] <= pipeline[0];
        pipeline[2] <= pipeline[1];
    end
end

assign debounceout = &pipeline; 

endmodule
