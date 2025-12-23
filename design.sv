`timescale 1ns/1ps
// ================================================================
// INSTRUCTION FETCH (IF)
// ================================================================
module if_stage (
    input  wire        clk,
    input  wire        rst,
    input  wire        stall,
    output reg  [31:0] pc_out,
    output reg  [31:0] instr_out
);
    reg [31:0] pc;
    reg [31:0] imem [0:15];

    // Program: RAW hazard (ADDI -> ADD)
    initial begin
        imem[0] = 32'h00500093; // ADDI x1, x0, 5
        imem[1] = 32'h00108133; // ADD  x2, x1, x1
        imem[2] = 32'h00000013; // NOP
        imem[3] = 32'h00000013; // NOP
    end

    always @(posedge clk) begin
        if (rst) begin
            pc        <= 32'd0;
            pc_out    <= 32'd0;
            instr_out <= 32'd0;
        end else if (!stall) begin
            pc_out    <= pc;
            instr_out <= imem[pc[5:2]];
            pc        <= pc + 32'd4;
        end
        // else: hold on stall
    end
endmodule

// ================================================================
// IF / ID PIPELINE REGISTER
// ================================================================
module if_id_reg (
    input  wire        clk,
    input  wire        rst,
    input  wire        stall,
    input  wire [31:0] pc_if,
    input  wire [31:0] instr_if,
    output reg  [31:0] pc_id,
    output reg  [31:0] instr_id
);
    always @(posedge clk) begin
        if (rst) begin
            pc_id    <= 32'd0;
            instr_id <= 32'd0;
        end else if (!stall) begin
            pc_id    <= pc_if;
            instr_id <= instr_if;
        end
    end
endmodule

// ================================================================
// INSTRUCTION DECODE (ID) – Register File
// ================================================================
module id_stage (
    input  wire        clk,
    input  wire        rst,
    input  wire [31:0] instr_in,
    input  wire [31:0] wb_data,
    input  wire [4:0]  wb_rd,
    input  wire        wb_we,
    output wire [31:0] rs1_data,
    output wire [31:0] rs2_data
);
    reg [31:0] regfile [0:31];

    wire [4:0] rs1 = instr_in[19:15];
    wire [4:0] rs2 = instr_in[24:20];

    integer i;
    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < 32; i = i + 1)
                regfile[i] <= 32'd0;
        end else if (wb_we && (wb_rd != 5'd0)) begin
            regfile[wb_rd] <= wb_data;
        end
    end

    assign rs1_data = (rs1 == 5'd0) ? 32'd0 : regfile[rs1];
    assign rs2_data = (rs2 == 5'd0) ? 32'd0 : regfile[rs2];
endmodule

// ================================================================
// ID / EX PIPELINE REGISTER
// ================================================================
module id_ex_reg (
    input  wire        clk,
    input  wire        rst,
    input  wire        flush,
    input  wire [31:0] rs1_id,
    input  wire [31:0] rs2_id,
    input  wire [31:0] instr_id,
    output reg  [31:0] rs1_ex,
    output reg  [31:0] rs2_ex,
    output reg  [31:0] instr_ex
);
    always @(posedge clk) begin
        if (rst || flush) begin
            rs1_ex   <= 32'd0;
            rs2_ex   <= 32'd0;
            instr_ex <= 32'd0; // NOP bubble
        end else begin
            rs1_ex   <= rs1_id;
            rs2_ex   <= rs2_id;
            instr_ex <= instr_id;
        end
    end
endmodule

// ================================================================
// HAZARD DETECTION UNIT (RAW, NOP-SAFE)
// ================================================================
module hazard_unit (
    input  wire [4:0] rs1_id,
    input  wire [4:0] rs2_id,
    input  wire [4:0] rd_ex,
    input  wire       regwrite_ex,
    output wire       stall
);
    // NO LOAD IN PIPELINE YET → NO STALL NEEDED
    assign stall = 1'b0;
endmodule


// ================================================================
// FORWARDING UNIT
// ================================================================
module forwarding_unit (
    input  wire [4:0] rs1_ex,
    input  wire [4:0] rs2_ex,
    input  wire [4:0] rd_mem,
    input  wire       regwrite_mem,
    input  wire [4:0] rd_wb,
    input  wire       regwrite_wb,
    output reg  [1:0] forward_a,
    output reg  [1:0] forward_b
);
    always @(*) begin
        forward_a = 2'b00;
        forward_b = 2'b00;

        // EX/MEM has priority
        if (regwrite_mem && (rd_mem != 0) && (rd_mem == rs1_ex))
            forward_a = 2'b10;
        if (regwrite_mem && (rd_mem != 0) && (rd_mem == rs2_ex))
            forward_b = 2'b10;

        // MEM/WB
        if (regwrite_wb && (rd_wb != 0) &&
            !(regwrite_mem && (rd_mem != 0) && (rd_mem == rs1_ex)) &&
            (rd_wb == rs1_ex))
            forward_a = 2'b01;

        if (regwrite_wb && (rd_wb != 0) &&
            !(regwrite_mem && (rd_mem != 0) && (rd_mem == rs2_ex)) &&
            (rd_wb == rs2_ex))
            forward_b = 2'b01;
    end
endmodule

// ================================================================
// EXECUTE (EX) – ALU
// ================================================================
module ex_stage (
    input  wire [31:0] rs1_data,
    input  wire [31:0] rs2_data,
    input  wire [31:0] instr_in,
    output reg  [31:0] alu_result
);
    wire [6:0] opcode = instr_in[6:0];
    wire [2:0] funct3 = instr_in[14:12];
    wire [6:0] funct7 = instr_in[31:25];

    always @(*) begin
        alu_result = 32'd0;
        case (opcode)
            7'b0110011: begin // R-type
                case ({funct7, funct3})
                    {7'b0000000,3'b000}: alu_result = rs1_data + rs2_data; // ADD
                    {7'b0100000,3'b000}: alu_result = rs1_data - rs2_data; // SUB
                endcase
            end
            7'b0010011: begin // ADDI
                alu_result = rs1_data + {{20{instr_in[31]}}, instr_in[31:20]};
            end
        endcase
    end
endmodule

// ================================================================
// EX / MEM PIPELINE REGISTER
// ================================================================
module ex_mem_reg (
    input  wire        clk,
    input  wire        rst,
    input  wire [31:0] alu_ex,
    input  wire [31:0] instr_ex,
    output reg  [31:0] alu_mem,
    output reg  [31:0] instr_mem
);
    always @(posedge clk) begin
        if (rst) begin
            alu_mem   <= 32'd0;
            instr_mem <= 32'd0;
        end else begin
            alu_mem   <= alu_ex;
            instr_mem <= instr_ex;
        end
    end
endmodule

// ================================================================
// MEM / WB PIPELINE REGISTER
// ================================================================
module mem_wb_reg (
    input  wire        clk,
    input  wire        rst,
    input  wire [31:0] alu_mem,
    input  wire [31:0] instr_mem,
    output reg  [31:0] alu_wb,
    output reg  [31:0] instr_wb
);
    always @(posedge clk) begin
        if (rst) begin
            alu_wb   <= 32'd0;
            instr_wb <= 32'd0;
        end else begin
            alu_wb   <= alu_mem;
            instr_wb <= instr_mem;
        end
    end
endmodule

// ================================================================
// WRITE BACK (WB)
// ================================================================
module wb_stage (
    input  wire [31:0] alu_result,
    input  wire [31:0] instr_in,
    output wire [31:0] wb_data,
    output wire [4:0]  wb_rd,
    output wire        wb_we
);
    wire [6:0] opcode = instr_in[6:0];

    assign wb_rd   = instr_in[11:7];
    assign wb_data = alu_result;

    // NOP-safe write enable
    assign wb_we =
    (instr_in == 32'd0) ? 1'b0 :
    (((opcode == 7'b0110011) || (opcode == 7'b0010011)) &&
     (wb_rd != 5'd0));
endmodule

// ================================================================
// ======================= CPU TOP ================================
// ================================================================
module cpu_top (
    input wire clk,
    input wire rst
);
    // IF
    wire [31:0] pc_if, instr_if;

    // IF/ID
    wire [31:0] pc_id, instr_id;

    // ID
    wire [31:0] rs1_id_data, rs2_id_data;

    // ID/EX
    wire [31:0] rs1_ex, rs2_ex, instr_ex;

    // EX
    wire [31:0] alu_ex;

    // EX/MEM
    wire [31:0] alu_mem, instr_mem;

    // MEM/WB
    wire [31:0] alu_wb, instr_wb;

    // WB
    wire [31:0] wb_data;
    wire [4:0]  wb_rd;
    wire        wb_we;

    // Hazard
    wire [4:0] rs1_id = instr_id[19:15];
    wire [4:0] rs2_id = instr_id[24:20];
    wire [4:0] rd_ex  = instr_ex[11:7];
    wire [6:0] ex_op  = instr_ex[6:0];

    wire regwrite_ex =
        (instr_ex != 32'd0) &&
        ((ex_op == 7'b0110011) || (ex_op == 7'b0010011)) &&
        (rd_ex != 5'd0);

    wire stall;

    // Forwarding
    wire [1:0] fwd_a, fwd_b;
    wire [4:0] rs1_ex_n = instr_ex[19:15];
    wire [4:0] rs2_ex_n = instr_ex[24:20];
    wire [4:0] rd_mem   = instr_mem[11:7];

    wire regwrite_mem =
        (instr_mem != 32'd0) &&
        ((instr_mem[6:0] == 7'b0110011) || (instr_mem[6:0] == 7'b0010011)) &&
        (rd_mem != 5'd0);

    // Instantiate stages
    if_stage IF (.clk(clk), .rst(rst), .stall(stall), .pc_out(pc_if), .instr_out(instr_if));
    if_id_reg IFID (.clk(clk), .rst(rst), .stall(stall), .pc_if(pc_if), .instr_if(instr_if), .pc_id(pc_id), .instr_id(instr_id));
    id_stage ID (.clk(clk), .rst(rst), .instr_in(instr_id), .wb_data(wb_data), .wb_rd(wb_rd), .wb_we(wb_we),
                 .rs1_data(rs1_id_data), .rs2_data(rs2_id_data));
    id_ex_reg IDEX (.clk(clk), .rst(rst), .flush(stall), .rs1_id(rs1_id_data), .rs2_id(rs2_id_data),
                    .instr_id(instr_id), .rs1_ex(rs1_ex), .rs2_ex(rs2_ex), .instr_ex(instr_ex));

    hazard_unit HU (.rs1_id(rs1_id), .rs2_id(rs2_id), .rd_ex(rd_ex), .regwrite_ex(regwrite_ex), .stall(stall));

    forwarding_unit FU (
        .rs1_ex(rs1_ex_n), .rs2_ex(rs2_ex_n),
        .rd_mem(rd_mem), .regwrite_mem(regwrite_mem),
        .rd_wb(wb_rd), .regwrite_wb(wb_we),
        .forward_a(fwd_a), .forward_b(fwd_b)
    );

    wire [31:0] alu_in1 =
        (fwd_a == 2'b10) ? alu_mem :
        (fwd_a == 2'b01) ? wb_data : rs1_ex;

    wire [31:0] alu_in2 =
        (fwd_b == 2'b10) ? alu_mem :
        (fwd_b == 2'b01) ? wb_data : rs2_ex;

    ex_stage EX (.rs1_data(alu_in1), .rs2_data(alu_in2), .instr_in(instr_ex), .alu_result(alu_ex));
    ex_mem_reg EXMEM (.clk(clk), .rst(rst), .alu_ex(alu_ex), .instr_ex(instr_ex), .alu_mem(alu_mem), .instr_mem(instr_mem));
    mem_wb_reg MEMWB (.clk(clk), .rst(rst), .alu_mem(alu_mem), .instr_mem(instr_mem), .alu_wb(alu_wb), .instr_wb(instr_wb));
    wb_stage WB (.alu_result(alu_wb), .instr_in(instr_wb), .wb_data(wb_data), .wb_rd(wb_rd), .wb_we(wb_we));
endmodule
