module gpr_s(
    output wire [31:0] a, b,
    input  wire [4:0]  rs, rt, num_write,
    input  wire [31:0] data_write,
    input  wire        reg_write, 
    input  wire        clk, rst
);

    reg [31:0] gp_registers[31:0];
    integer i;  

    assign a = rs ? gp_registers[rs] : 0;  // 0号寄存器永远返回0
    assign b = rt ? gp_registers[rt] : 0;
    always @(posedge clk) begin
        if (rst)     for (i = 0; i < 32; i = i + 1)  gp_registers[i] <= 32'b0;
        else if (reg_write && num_write)     gp_registers[num_write] <= data_write; 
    end

endmodule

module gpr(
    input  wire         clk, rst, reg_write, IF_ID_write,        
    input  wire [4:0]   rs, rt, num_write,
    output wire [31:0]  a, b,
    input  wire [31:0]  data_write
);
    reg  [4:0]  rs_2, rt_2, num_write_2;
    reg  [31:0] data_write_2;
    wire [31:0] out_a, out_b;
    reg         reg_write_2;

    always @(posedge clk) begin
        if (rst) begin
            rs_2 <= 5'b0; rt_2 <= 5'b0; num_write_2 <= 5'b0; reg_write_2 <= 1'b0;
        end else if(!IF_ID_write) begin
            rs_2 <= rs_2; rt_2 <= rt_2; 
            num_write_2 <= num_write; reg_write_2 <= reg_write; data_write_2 <= data_write;
        end else begin
            rs_2 <= rs; rt_2 <= rt; 
            num_write_2 <= num_write; reg_write_2 <= reg_write; data_write_2 <= data_write;
        end
    end     

    wire ok_sw = reg_write;
    wire [4:0] rs_ask = IF_ID_write ? rs : rs_2;
    wire [4:0] rt_ask = IF_ID_write ? rt : rt_2;
    wire rs_bypass = (num_write_2 == rs_2) && reg_write_2;
    wire rt_bypass = (num_write_2 == rt_2) && reg_write_2;

    blk_mem_gen_0 mem_0(   
                    .clka(clk), .addra(num_write), .dina(data_write),
                    .ena(reg_write), .wea(ok_sw),
                    .clkb(clk), .addrb(rs_ask), .doutb(out_a)
    );
    
    blk_mem_gen_0 mem_1(   
                    .clka(clk), .addra(num_write), .dina(data_write),
                    .ena(reg_write), .wea(ok_sw),
                    .clkb(clk), .addrb(rt_ask), .doutb(out_b) 
    );
    
    assign a = rs_bypass ? data_write_2 : out_a;
    assign b = rt_bypass ? data_write_2 : out_b;

endmodule


module pc(
        output reg  [31:0]  pc,
        input  wire         clk,
        input  wire         rst, pc_write,
        input  wire [31:0]  npc
    );
    
    parameter pc_init = 32'h8000_0000;
    always@(posedge clk) begin
        if(rst)     pc <= pc_init;
        else        pc <= pc_write ? npc : pc;
    end

endmodule


module alu (
        output reg [31:0] c,
        input wire [31:0] a, b,
        input wire [4:0]  shamt,
        input wire [7:0]  d_aluop
    );

    always @(*) begin
        case (1'b1) 
            d_aluop[0]:  c = b;                      
            d_aluop[1]:  c = a + b;                  
            d_aluop[2]:  c = a - b;                  
            d_aluop[3]:  c = a & b;                 
            d_aluop[4]:  c = a | b;                 
            d_aluop[5]:  c = a ^ b;                                 
            d_aluop[6]:  c = b << shamt;                     
            d_aluop[7]:  c = b >> shamt;            
            default:     c = 32'b0;               
        endcase
    end

endmodule



module multiplier(
        input wire  [31:0] a, b,
        output wire [31:0] c,
        input wire clk
    );
    // Booth2编码
    wire [31:0] pp [16:0];  // 17个部分积,只保留低32位
    wire [34:0] b_extended = {{2{b[31]}}, b, 1'b0}; 

    genvar i;
    generate
        for (i = 0; i < 17; i = i + 1) begin : booth_gen
            wire [2:0] booth_code = b_extended[2*i+2 -: 3];  // 选择3位编码
            reg [31:0] pp_temp; // Booth解码器
            always @(*) begin
                case (booth_code)
                    3'b000, 3'b111: pp_temp = 31'd0;    // 0
                    3'b001, 3'b010: pp_temp = a;        // +A
                    3'b011:         pp_temp = {a[30:0], 1'b0};        // +2A
                    3'b100:         pp_temp = ~{a[30:0], 1'b0} + 1;   // -2A
                    3'b101, 3'b110: pp_temp = ~a + 1;   // -A
                endcase
            end
            
            assign pp[i] = pp_temp << (i * 2);
        end
    endgenerate
    
    
    // 华莱士树压缩结构（3级3:2压缩器）
    wire [31:0] s1[12:0], c1[12:0];
    // 第一级压缩器
    csa_adder csa1_0(pp[0], pp[1], pp[2], s1[0], c1[0]);
    csa_adder csa1_1(pp[3], pp[4], pp[5], s1[1], c1[1]);
    csa_adder csa1_2(pp[6], pp[7], pp[8], s1[2], c1[2]);
    csa_adder csa1_3(pp[9], pp[10], pp[11], s1[3], c1[3]);
    csa_adder csa1_4(pp[12], pp[13], pp[14], s1[4], c1[4]);

    // 第二级压缩器
    csa_adder csa1_5(s1[0], c1[0], s1[3], s1[5], c1[5]);
    csa_adder csa1_6(s1[1], c1[1], c1[3], s1[6], c1[6]);
    csa_adder csa1_7(s1[2], c1[2], s1[4], s1[7], c1[7]);
    csa_adder csa1_8(c1[4], pp[15], pp[16], s1[8], c1[8]);
    
    
    // 第三级压缩器
    csa_adder csa1_9(s1[5], c1[5], c1[7], s1[9], c1[9]);
    csa_adder csa1_10(s1[6], c1[6], s1[7], s1[10], c1[10]);
    
    // 第四级压缩器
    csa_adder csa1_11(s1[8], s1[9], s1[10], s1[11], c1[11]);
    csa_adder csa1_12(c1[8], c1[9], c1[10], s1[12], c1[12]);
   
    reg [31:0] mult_reg[3:0];
    always @(posedge clk) begin
        mult_reg[0] <= s1[11]; mult_reg[1] <= c1[11];
        mult_reg[2] <= s1[12]; mult_reg[3] <= c1[12];
    end

    // 第五级加法器
    wire [31:0] ss1 = mult_reg[0] + mult_reg[1];
    wire [31:0] ss2 = mult_reg[2] + mult_reg[3];
    
    // 输出结果（低32位）
    assign c = ss1 + ss2;
endmodule


module csa_adder(
        input  wire [31:0] a, b, c,        
        output wire [31:0] sum, carry 
    );
    assign sum = a ^ b ^ c; 
    assign carry = ((a & b) | (b & c) | (c & a)) << 1; 

endmodule

