// alu_16bit_pipeline.v

module alu_16bit_pipeline #(
    parameter WIDTH = 16
)(
    input  wire                 clk,
    input  wire                 rst_n,      // active-low SYNCHRONOUS reset
    input  wire                 in_valid,   // operands valid this cycle
    input  wire [3:0]           opcode,
    input  wire [WIDTH-1:0]     a,
    input  wire [WIDTH-1:0]     b,
    output reg                  out_valid,  // result valid this cycle
    output reg  [WIDTH-1:0]     result,
    output reg                  zero,       // result == 0
    output reg                  carry,      // add: carry-out / sub: borrow
    output reg                  overflow,   // signed overflow (add/sub)
    output reg                  negative    // result MSB (signed sign bit)
);

    // ---- Opcode encoding ----
    localparam [3:0] OP_ADD   = 4'h0;
    localparam [3:0] OP_SUB   = 4'h1;
    localparam [3:0] OP_AND   = 4'h2;
    localparam [3:0] OP_OR    = 4'h3;
    localparam [3:0] OP_XOR   = 4'h4;
    localparam [3:0] OP_NOT   = 4'h5;  // ~a
    localparam [3:0] OP_SLL   = 4'h6;  // a << b[4:0]
    localparam [3:0] OP_SRL   = 4'h7;  // a >> b[4:0]  (logical)
    localparam [3:0] OP_SRA   = 4'h8;  // a >>> b[4:0] (arithmetic)
    localparam [3:0] OP_ROL   = 4'h9;  // rotate left  by b[3:0]
    localparam [3:0] OP_ROR   = 4'hA;  // rotate right by b[3:0]
    localparam [3:0] OP_SLT   = 4'hB;  // signed   a<b -> 1
    localparam [3:0] OP_SLTU  = 4'hC;  // unsigned a<b -> 1
    localparam [3:0] OP_EQ    = 4'hD;  // a==b -> 1
    localparam [3:0] OP_PASSB = 4'hE;  // pass b
    localparam [3:0] OP_PASSA = 4'hF;  // pass a

 
    // Stage 1 : register inputs
    
    reg [WIDTH-1:0] a_r, b_r;
    reg [3:0]       op_r;
    reg             v_r1;

    always @(posedge clk) begin
        if (!rst_n) begin
            a_r  <= {WIDTH{1'b0}};
            b_r  <= {WIDTH{1'b0}};
            op_r <= 4'h0;
            v_r1 <= 1'b0;
        end else begin
            a_r  <= a;
            b_r  <= b;
            op_r <= opcode;
            v_r1 <= in_valid;
        end
    end
    // Combinational compute on the REGISTERED operands
    wire [4:0]      shamt = b_r[4:0];          // 0..31 shift amount
    reg  [WIDTH:0]  add_ext, sub_ext;          // +1 bit for carry/borrow
    reg  [WIDTH-1:0] c_result;
    reg             c_carry, c_ovf;

    always @(*) begin
        add_ext  = {1'b0, a_r} + {1'b0, b_r};
        sub_ext  = {1'b0, a_r} - {1'b0, b_r};
        c_result = {WIDTH{1'b0}};
        c_carry  = 1'b0;
        c_ovf    = 1'b0;
        case (op_r)
            OP_ADD: begin
                c_result = add_ext[WIDTH-1:0];
                c_carry  = add_ext[WIDTH];
                // signed overflow: operands same sign, result differs
                c_ovf    = (a_r[WIDTH-1] == b_r[WIDTH-1]) &&
                           (c_result[WIDTH-1] != a_r[WIDTH-1]);
            end
            OP_SUB: begin
                c_result = sub_ext[WIDTH-1:0];
                c_carry  = sub_ext[WIDTH];      // borrow
                c_ovf    = (a_r[WIDTH-1] != b_r[WIDTH-1]) &&
                           (c_result[WIDTH-1] != a_r[WIDTH-1]);
            end
            OP_AND:   c_result = a_r & b_r;
            OP_OR:    c_result = a_r | b_r;
            OP_XOR:   c_result = a_r ^ b_r;
            OP_NOT:   c_result = ~a_r;
            OP_SLL:   c_result = a_r << shamt;
            OP_SRL:   c_result = a_r >> shamt;
            OP_SRA:   c_result = $signed(a_r) >>> shamt;
            OP_ROL:   c_result = (a_r << b_r[3:0]) | (a_r >> (WIDTH - b_r[3:0]));
            OP_ROR:   c_result = (a_r >> b_r[3:0]) | (a_r << (WIDTH - b_r[3:0]));
            OP_SLT:   c_result = ($signed(a_r) < $signed(b_r)) ? 16'h0001 : 16'h0000;
            OP_SLTU:  c_result = (a_r < b_r)                   ? 16'h0001 : 16'h0000;
            OP_EQ:    c_result = (a_r == b_r)                  ? 16'h0001 : 16'h0000;
            OP_PASSB: c_result = b_r;
            OP_PASSA: c_result = a_r;
            default:  c_result = {WIDTH{1'b0}};
        endcase
    end


    // Stage 2 : register outputs

    always @(posedge clk) begin
        if (!rst_n) begin
            result    <= {WIDTH{1'b0}};
            zero      <= 1'b0;
            carry     <= 1'b0;
            overflow  <= 1'b0;
            negative  <= 1'b0;
            out_valid <= 1'b0;
        end else begin
            result    <= c_result;
            zero      <= (c_result == {WIDTH{1'b0}});
            carry     <= c_carry;
            overflow  <= c_ovf;
            negative  <= c_result[WIDTH-1];
            out_valid <= v_r1;
        end
    end

endmodule
