// alu_16bit_pipeline_tb.sv

`timescale 1ns/1ps

module alu_16bit_pipeline_tb;

    localparam int WIDTH = 16;
    localparam     CLK_P = 10;   // 10 ns -> 100 MHz

    // ---- DUT I/O ----
    logic                 clk, rst_n, in_valid;
    logic [3:0]           opcode;
    logic [WIDTH-1:0]     a, b;
    logic                 out_valid;
    logic [WIDTH-1:0]     result;
    logic                 zero, carry, overflow, negative;

    // ---- DUT ----
    alu_16bit_pipeline #(.WIDTH(WIDTH)) dut (
        .clk(clk), .rst_n(rst_n), .in_valid(in_valid),
        .opcode(opcode), .a(a), .b(b),
        .out_valid(out_valid), .result(result),
        .zero(zero), .carry(carry), .overflow(overflow), .negative(negative)
    );

    // ---- Clock ----
    initial clk = 1'b0;
    always #(CLK_P/2) clk = ~clk;

    // ---- Scoreboard entry ----
    typedef struct packed {
        logic [WIDTH-1:0] exp_result;
        logic             exp_zero;
        logic             exp_carry;
        logic             exp_overflow;
        logic             exp_negative;
        logic [3:0]       op;
        logic [WIDTH-1:0] a;
        logic [WIDTH-1:0] b;
    } expected_t;

    expected_t sb [$];          // scoreboard FIFO
    int pass_cnt = 0;
    int fail_cnt = 0;

    // ---- Reference model ----
    function automatic expected_t ref_model(input logic [3:0] op,
                                            input logic [WIDTH-1:0] av,
                                            input logic [WIDTH-1:0] bv);
        expected_t  e;
        logic [WIDTH:0]   add_ext, sub_ext;
        logic [4:0]       shamt;
        logic [WIDTH-1:0] r;
        logic             c, ov;
        shamt   = bv[4:0];
        add_ext = {1'b0, av} + {1'b0, bv};
        sub_ext = {1'b0, av} - {1'b0, bv};
        r = '0; c = 1'b0; ov = 1'b0;
        case (op)
            4'h0: begin r = add_ext[WIDTH-1:0]; c = add_ext[WIDTH];
                        ov = (av[WIDTH-1]==bv[WIDTH-1]) && (r[WIDTH-1]!=av[WIDTH-1]); end
            4'h1: begin r = sub_ext[WIDTH-1:0]; c = sub_ext[WIDTH];
                        ov = (av[WIDTH-1]!=bv[WIDTH-1]) && (r[WIDTH-1]!=av[WIDTH-1]); end
            4'h2: r = av & bv;
            4'h3: r = av | bv;
            4'h4: r = av ^ bv;
            4'h5: r = ~av;
            4'h6: r = av << shamt;
            4'h7: r = av >> shamt;
            4'h8: r = $signed(av) >>> shamt;
            4'h9: r = (av << bv[3:0]) | (av >> (WIDTH - bv[3:0]));
            4'hA: r = (av >> bv[3:0]) | (av << (WIDTH - bv[3:0]));
            4'hB: r = ($signed(av) < $signed(bv)) ? 16'h1 : 16'h0;
            4'hC: r = (av < bv)                   ? 16'h1 : 16'h0;
            4'hD: r = (av == bv)                  ? 16'h1 : 16'h0;
            4'hE: r = bv;
            4'hF: r = av;
        endcase
        e.exp_result   = r;
        e.exp_zero     = (r == '0);
        e.exp_carry    = c;
        e.exp_overflow = ov;
        e.exp_negative = r[WIDTH-1];
        e.op = op; e.a = av; e.b = bv;
        return e;
    endfunction

    // ---- Driver: one transaction, advances one clock, pushes expected ----
    task automatic drive(input logic [3:0] op,
                         input logic [WIDTH-1:0] av,
                         input logic [WIDTH-1:0] bv);
        @(negedge clk);
        in_valid = 1'b1;
        opcode   = op;
        a        = av;
        b        = bv;
        sb.push_back(ref_model(op, av, bv));
    endtask

    // ---- Checker: on negedge, when out_valid, pop & compare ----
    expected_t cur;
    always @(negedge clk) begin
        if (rst_n && out_valid) begin
            if (sb.size() == 0) begin
                $error("[%0t] out_valid asserted but scoreboard EMPTY", $time);
                fail_cnt++;
            end else begin
                cur = sb.pop_front();
                if (result    === cur.exp_result   &&
                    zero      === cur.exp_zero      &&
                    carry     === cur.exp_carry     &&
                    overflow  === cur.exp_overflow  &&
                    negative  === cur.exp_negative) begin
                    pass_cnt++;
                end else begin
                    fail_cnt++;
                    $error("[%0t] MISMATCH op=%h a=%h b=%h | got R=%h Z=%b C=%b V=%b N=%b | exp R=%h Z=%b C=%b V=%b N=%b",
                        $time, cur.op, cur.a, cur.b,
                        result, zero, carry, overflow, negative,
                        cur.exp_result, cur.exp_zero, cur.exp_carry,
                        cur.exp_overflow, cur.exp_negative);
                end
            end
        end
    end

    // ---- Waveform dump ----
    initial begin
`ifdef FSDB
        $fsdbDumpfile("alu.fsdb");
        $fsdbDumpvars(0, alu_16bit_pipeline_tb);
`else
        $dumpfile("alu.vcd");
        $dumpvars(0, alu_16bit_pipeline_tb);
`endif
    end

    // ---- Stimulus ----
    initial begin
        rst_n = 1'b0; in_valid = 1'b0; opcode = 4'h0; a = '0; b = '0;
        repeat (3) @(negedge clk);
        rst_n = 1'b1;

        // ---------- Directed corner cases  ----------
        drive(4'h0, 16'h7FFF, 16'h0001); // ADD: +ovf, 0x7FFF+1=0x8000, N=1 V=1
        drive(4'h0, 16'hFFFF, 16'h0001); // ADD: carry-out, result 0, C=1 Z=1
        drive(4'h1, 16'h0000, 16'h0001); // SUB: borrow, C(borrow)=1
        drive(4'h1, 16'h8000, 16'h0001); // SUB: signed overflow
        drive(4'h2, 16'hAAAA, 16'h5555); // AND -> 0x0000, Z=1
        drive(4'h3, 16'hAAAA, 16'h5555); // OR  -> 0xFFFF
        drive(4'h4, 16'hFFFF, 16'hFFFF); // XOR -> 0x0000, Z=1
        drive(4'h5, 16'h0F0F, 16'h0000); // NOT -> 0xF0F0
        drive(4'h6, 16'h0001, 16'h0004); // SLL by 4 -> 0x0010
        drive(4'h7, 16'h8000, 16'h0004); // SRL by 4 -> 0x0800
        drive(4'h8, 16'h8000, 16'h0004); // SRA by 4 -> 0xF800 (sign-extend)
        drive(4'h9, 16'h1234, 16'h0004); // ROL by 4
        drive(4'hA, 16'h1234, 16'h0004); // ROR by 4
        drive(4'hB, 16'hFFFF, 16'h0001); // SLT signed: -1 < 1 -> 1
        drive(4'hC, 16'hFFFF, 16'h0001); // SLTU: 65535 < 1 -> 0
        drive(4'hD, 16'h1234, 16'h1234); // EQ -> 1
        drive(4'hE, 16'h1111, 16'h2222); // PASS B -> 0x2222
        drive(4'hF, 16'h1111, 16'h2222); // PASS A -> 0x1111

        // ---------- Insert a bubble (in_valid low) ----------
        @(negedge clk) in_valid = 1'b0;
        @(negedge clk);

        // ---------- Random regression ----------
        for (int i = 0; i < 200; i++)
            drive($urandom_range(0,15), $urandom, $urandom);

        // ---------- Drain the pipeline ----------
        @(negedge clk) in_valid = 1'b0;
        repeat (5) @(negedge clk);

        // ---------- Report ----------
        $display("==================================================");
        $display("  ALU_16BIT_PIPELINE TEST COMPLETE");
        $display("    PASS = %0d    FAIL = %0d", pass_cnt, fail_cnt);
        if (sb.size() != 0)
            $display("    WARNING: %0d expected results never checked", sb.size());
        if (fail_cnt == 0 && sb.size() == 0)
            $display("    RESULT: ALL TESTS PASSED");
        else
            $display("    RESULT: FAILURES DETECTED");
        $display("==================================================");
        $finish;
    end

    // ---- Safety timeout ----
    initial begin
        #100000;
        $display("TIMEOUT - simulation did not finish");
        $finish;
    end

endmodule
