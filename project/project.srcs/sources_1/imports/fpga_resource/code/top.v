module top(
    input clk,
    
    // switchs
    input [15:0]  sw,
    // buttons
    input         btnC,
    input         btnU,
    input         btnL,
    input         btnR,

    // seg
    output [ 6:0] seg,
    output [ 3:0] an,
    // LED
    output [15:0] led
);


wire [ 3:0] numbers;
wire        reset = sw[15];
wire        clk_div, clk_temp;


wire        btnC_stable, btnU_stable, btnL_stable, btnR_stable;
wire [15:0] sw_stable;

wire [ 2:0] temp_outside = sw_stable[11:9];
wire [ 2:0] temp_desired = sw_stable[14:12];
wire [ 3:0] temp_lo;
wire [ 3:0] temp_hi = 4'd2;
wire        temp_en;

wire        seg_clk;

reg [2:0] an_cnt;
always @(posedge seg_clk) begin
    an_cnt <= an_cnt + 1'b1;
end

assign an = (~(4'b0001 << an_cnt[2:1]) | {~temp_en, ~temp_en, 1'b1, 1'b0}) | {4{an_cnt[0]}};
wire [3:0] bcd = ({4{an_cnt == 3'b000}} & numbers) |  
                 ({4{an_cnt == 3'b100}} & temp_lo) | 
                 ({4{an_cnt == 3'd110}} & temp_hi) ;

clockDividerHB #(.THRESHOLD(100_000)) clockDividerHB_seg(
    .reset          (reset      ), 
    .enable         (1'b1       ), 
    .clk            (clk        ), 
    .dividedClk     (seg_clk   ), 
    .beat           (           )
);

clockDividerHB #(.THRESHOLD(25_000_000)) clockDividerHB_temp(
    .reset          (reset      ), 
    .enable         (1'b1       ), 
    .clk            (clk        ), 
    .dividedClk     (clk_temp   ), 
    .beat           (           )
);

temp temp_i(
    .clk            (clk_temp   ),
    .reset          (reset      ),
    .temp_out       (temp_outside),
    .temp_set       (temp_desired),
    .num            (numbers    ),
    .enable         (temp_en    ),
    .temp_curr      (temp_lo    )
);

debouncer debouncer_btnC (
    .switchIn       (btnC       ),
    .clk            (clk        ),
    .reset          (reset      ), 
    .debounceout    (btnC_stable)
);

debouncer debouncer_btnU (
    .switchIn       (btnU       ),
    .clk            (clk        ),
    .reset          (reset      ), 
    .debounceout    (btnU_stable)
);

debouncer debouncer_btnL (
    .switchIn       (btnL       ),
    .clk            (clk        ),
    .reset          (reset      ), 
    .debounceout    (btnL_stable)
);

debouncer debouncer_btnR (
    .switchIn       (btnR       ),
    .clk            (clk        ),
    .reset          (reset      ), 
    .debounceout    (btnR_stable)
);

genvar i;
generate for(i = 0; i < 16; i = i + 1) begin:sw_stable_deb
    debouncer debouncer_sw_i (
        .switchIn       (sw[i]      ),
        .clk            (clk        ),
        .reset          (reset      ), 
        .debounceout    (sw_stable[i])
    );
end
endgenerate

clockDividerHB #(.THRESHOLD(50_000_000)) clockDividerHB_i(
    .reset          (reset      ), 
    .enable         (1'b1       ), 
    .clk            (clk        ), 
    .dividedClk     (clk_div    ), 
    .beat           (           )
);

smart_valut smart_valut_i(
    .clk            (clk_div    ),
    .reset          (reset      ),
    .pin_code       (sw_stable[6:0]),
    .ENTER          (btnC_stable),
    .SECURITY_RESET (btnU_stable),
    .MORSE          (btnL_stable),
    .DOOR_MASTER    (btnR_stable),
    .person_enter   (sw_stable[7]),
    .person_exit    (sw_stable[8]),

    .status_door    (led[3:0]   ),
    .status_alarm   (led[7:4]   ),
    .person_num     (numbers    )
);

sevenSegmentDecoder sevenSegmentDecoder_i(
    .bcd            (bcd        ),
    .ssd            (seg        )
);

assign led[15] = clk_div;
assign led[14] = reset;


endmodule


module temp(
    input         clk,
    input         reset,
    input  [ 2:0] temp_out,
    input  [ 2:0] temp_set,
    input  [ 3:0] num,

    output reg    enable,
    output reg [ 3:0] temp_curr
);

reg [5:0] disable_cnt;
always @(posedge clk) begin
    if (reset) disable_cnt <= 6'd40;
    else if (num != 0) disable_cnt <= 6'd40;
    else if (disable_cnt != 0)  disable_cnt <= disable_cnt - 6'b1;
    else disable_cnt <= disable_cnt;
end

always @(posedge clk) begin
    if (reset) enable <= 1'b0;
    else if (num != 0) enable <= 1'b1;
    else if (disable_cnt == 0)  enable <= 1'b0;
    else enable <= enable;
end

reg [1:0] cnt;

always @(posedge clk) begin
    cnt <= cnt + 1'b1;
end

wire clk2s = cnt == 2'b00;
wire clk1s = cnt == 2'b00 || cnt == 2'b10;

always @(posedge clk) begin
    if (reset) temp_curr <= {1'b0, temp_out};
    else begin
        if (num == 0) begin
            if ((temp_curr[2:0] != temp_out) && clk2s && temp_curr[2:0] > temp_out) temp_curr <= temp_curr - 1'b1;
            else if ((temp_curr[2:0] != temp_out) && clk2s && temp_curr[2:0] < temp_out) temp_curr <= temp_curr + 1'b1;
            else temp_curr <= temp_curr;
        end else if (num > 5) begin
            if ((temp_curr[2:0] != temp_set) && clk1s && temp_curr[2:0] > temp_set) temp_curr <= temp_curr - 1'b1;
            else if ((temp_curr[2:0] != temp_set) && clk1s && temp_curr[2:0] < temp_set) temp_curr <= temp_curr + 1'b1;
            else temp_curr <= temp_curr;
        end else begin 
            if ((temp_curr[2:0] != temp_set) && temp_curr[2:0] > temp_set) temp_curr <= temp_curr - 1'b1;
            else if ((temp_curr[2:0] != temp_set) && temp_curr[2:0] < temp_set) temp_curr <= temp_curr + 1'b1;
            else temp_curr <= temp_curr;
        end
    end
end

endmodule


module smart_valut(
    input         clk,
    input         reset,
    input  [ 6:0] pin_code,
    input         ENTER,
    input         SECURITY_RESET,
    input         MORSE,
    input         DOOR_MASTER,
    input         person_enter,
    input         person_exit,

    output [ 3:0] status_door,
    output [ 3:0] status_alarm,
    output reg [ 3:0] person_num
);

localparam S_DOOR_CLOSED        = 4'h0;
localparam S_DOOR_ENTER_OPENING = 4'h1;
localparam S_DOOR_ENTER_OPENED  = 4'h2;
localparam S_DOOR_ENTER_CLOSING = 4'h3;
localparam S_DOOR_ENTER_CLOSED  = 4'h4;
localparam S_DOOR_EXIT_OPENING  = 4'h5;
localparam S_DOOR_EXIT_OPENED   = 4'h6;
localparam S_DOOR_EXIT_CLOSING  = 4'h7;
localparam S_DOOR_CHANCE        = 4'h8;
localparam S_DOOR_TRAP          = 4'h9;

localparam PASSWD               = 7'd57;

reg  [ 3:0] state;
wire        person_full;

reg  [ 3:0] door_open_close_cnt;
always @(posedge clk) begin
    if (state == S_DOOR_CLOSED || state == S_DOOR_ENTER_CLOSED || state == S_DOOR_ENTER_OPENED || state == S_DOOR_EXIT_OPENED) begin
        door_open_close_cnt <= 4'b0;
    end else begin
        door_open_close_cnt <= door_open_close_cnt + 1'b1;
    end
end

reg  [ 5:0] door_open_close_timeout_cnt;
always @(posedge clk) begin
    if (state == S_DOOR_ENTER_OPENING || state == S_DOOR_EXIT_OPENING) begin
        door_open_close_timeout_cnt <= 4'b0;
    end else begin
        door_open_close_timeout_cnt <= door_open_close_timeout_cnt + 1'b1;
    end
end

reg  [ 5:0] door_chance_timeout_cnt;
always @(posedge clk) begin
    if (state == S_DOOR_CLOSED) begin
        door_chance_timeout_cnt <= 4'b0;
    end else begin
        door_chance_timeout_cnt <= door_chance_timeout_cnt + 1'b1;
    end
end

reg  [ 3:0] morse_hold_time;

always @(posedge clk) begin
    if (~MORSE) morse_hold_time <= 4'b0;
    else morse_hold_time <= morse_hold_time + 1'b1;
end

wire record_morse = ~MORSE && morse_hold_time != 0;

reg  [31:0] morse_input_cnt;

always @(posedge clk) begin
    if (state == S_DOOR_ENTER_CLOSING) morse_input_cnt <= 32'b0;
    else if (record_morse) morse_input_cnt <= morse_input_cnt + 1'b1;
end


reg  [ 9:0] door_exit_morse_seq;
always @(posedge clk) begin
    if (record_morse)
        door_exit_morse_seq <= {door_exit_morse_seq[8:0], morse_hold_time < 4'd3}; 
    else
        door_exit_morse_seq <= door_exit_morse_seq;
end

always @(posedge clk) begin
    if (reset || SECURITY_RESET) begin
        state <= S_DOOR_CLOSED;
    end else if (DOOR_MASTER) begin
        state <= S_DOOR_EXIT_OPENED;
    end else begin
        case (state) 
        S_DOOR_CLOSED: 
            if      (ENTER && pin_code == PASSWD) state <= S_DOOR_ENTER_OPENING;
            else if (ENTER && pin_code != PASSWD) state <= S_DOOR_CHANCE;
            else                                  state <= S_DOOR_CLOSED;
        S_DOOR_ENTER_OPENING: 
            if (door_open_close_cnt == 3'd4) state <= S_DOOR_ENTER_OPENED;
            else                             state <= S_DOOR_ENTER_OPENING;
        S_DOOR_ENTER_OPENED:
            if (door_open_close_timeout_cnt == 5'd30) state <= S_DOOR_ENTER_CLOSING;
            else                                                     state <= S_DOOR_ENTER_OPENED;
        S_DOOR_ENTER_CLOSING:
            if (door_open_close_cnt == 3'd4) state <= S_DOOR_ENTER_CLOSED;
            else                             state <= S_DOOR_ENTER_CLOSING;
        S_DOOR_ENTER_CLOSED: 
            if((door_exit_morse_seq == 10'd07 || door_exit_morse_seq == 10'd56 ||
                door_exit_morse_seq == 10'd37 || door_exit_morse_seq == 10'd10 ||
                door_exit_morse_seq == 10'd67 || door_exit_morse_seq == 10'd45 ||
                door_exit_morse_seq == 10'd23 || door_exit_morse_seq == 10'd72 ||
                door_exit_morse_seq == 10'd89 || door_exit_morse_seq == 10'd34 ||
                door_exit_morse_seq == 10'd78 || door_exit_morse_seq == 10'd92 )  && morse_input_cnt >= 32'd10)  state <= S_DOOR_EXIT_OPENING;
            else                                                                  state <= S_DOOR_ENTER_CLOSED;
        S_DOOR_EXIT_OPENING: 
            if (door_open_close_cnt == 3'd4) state <= S_DOOR_EXIT_OPENED;
            else                             state <= S_DOOR_EXIT_OPENING;
        S_DOOR_EXIT_OPENED:
            if (door_open_close_timeout_cnt == 5'd30) state <= S_DOOR_EXIT_CLOSING;
            else                                      state <= S_DOOR_EXIT_OPENED;
        S_DOOR_EXIT_CLOSING:
            if (door_open_close_cnt == 3'd4) state <= S_DOOR_CLOSED;
            else                             state <= S_DOOR_EXIT_CLOSING;
        S_DOOR_CHANCE:
            if (door_chance_timeout_cnt <= 5'd20 && ENTER && pin_code == PASSWD)         state <= S_DOOR_ENTER_OPENING;
            else if (door_chance_timeout_cnt > 5'd20 || (ENTER && pin_code != PASSWD))   state <= S_DOOR_TRAP;
            else                                                                         state <= S_DOOR_CHANCE;
        S_DOOR_TRAP: state <= S_DOOR_TRAP;
        endcase
    end
end

// LED for status_door
assign status_door = ({4{state == S_DOOR_CLOSED        || state == S_DOOR_ENTER_CLOSED}} &  (4'b1111                       )) |
                     ({4{state == S_DOOR_CHANCE        || state == S_DOOR_TRAP        }} &  (4'b1111                       )) |
                     ({4{state == S_DOOR_ENTER_OPENING || state == S_DOOR_EXIT_OPENING}} &  (4'b1111 << door_open_close_cnt)) |
                     ({4{state == S_DOOR_ENTER_CLOSING || state == S_DOOR_EXIT_CLOSING}} & ~(4'b1111 >> door_open_close_cnt)) ;

reg [1:0] cnt_for02s;

always @(posedge clk) begin
    if (reset) cnt_for02s <= 2'b0;
    else cnt_for02s <= cnt_for02s + 2'b1;
end

// LED for alarm
assign status_alarm = ({4{(state == S_DOOR_CHANCE) && cnt_for02s[1]}} & (4'b1111)) |
                      ({4{(state == S_DOOR_TRAP)   && clk          }} & (4'b1111)) ;

// person counter
assign person_full  = person_num == 4'd9;
assign person_empty = person_num == 4'd0;
assign allow_enter = (state == S_DOOR_ENTER_OPENED) || (state == S_DOOR_EXIT_OPENED);
always @(posedge clk) begin
    if (reset || SECURITY_RESET) begin
        person_num <= 4'b0;
    end
    else if (person_enter && person_exit && allow_enter) begin
        person_num <= person_num;
    end
    else if (person_enter && ~person_exit && allow_enter && !person_full) begin
        person_num <= person_num + 1'b1;
    end
    else if (~person_enter && person_exit && allow_enter && !person_empty) begin
        person_num <= person_num - 1'b1;
    end else begin
        person_num <= person_num;
    end
end
 
endmodule