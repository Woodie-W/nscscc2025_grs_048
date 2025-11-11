module ctrl_decode(
    input  wire [31:0]  instruction,
    output wire [7:0]   d_aluop,
    output wire         reg_write,
    output wire         r_type, i_type, j_type, 
    output wire [4:0]   gpr_wid, shamt,       
    output wire         s_lw, mem_write, s_byte,   //前�?�即mem_read, 后�?�为是否为�?�择单字�?
    output reg          s_jal, 
    output wire         s_pc_cal, s_b_a, s_b_b, s_quick,
    input  wire [31:0]  pc, pc_4, a_reg, b_reg,
    output wire [31:0]  b_in, npc, imme
);

parameter   SPECIAL = 6'b000000, SPECIAL2 = 6'b011100;
// R1-type  
parameter   ADD = 6'b100000, SUB = 6'b100010, ADDU = 6'b100001, JR = 6'b001000, 
            AND = 6'b100100, XOR = 6'b100110, OR = 6'b100101, JALR = 6'b001001,
            SLT = 6'b101010, SLL = 6'b000000, SRA = 6'b000011, SRL = 6'b000010, 
            SLLV = 6'b000100, SRLV = 6'b000110, SRAV = 6'b000111;
// R2-type
parameter   MUL = 6'b000010;
// I-type
parameter   LW = 6'b100011, SW = 6'b101011, LB = 6'b100000, SB = 6'b101000, 
            ORI = 6'b001101,  ANDI = 6'b001100, LUI = 6'b001111, XORI = 6'b001110,
            ADDI = 6'b001000, ADDIU = 6'b001001, BEQ = 6'b000100, BNE = 6'b000101, 
            BGEZ = 6'b000001, BLTZ = 6'b000001, BGTZ = 6'b000111, BLEZ = 6'b000110;
// J-type  
parameter   J = 6'b000010, JAL = 6'b000011;

//  指令删除说明:为了配合龙芯杯比赛进行优�?,这删除了部分指令以提升�?�能
//  删除的指令有: JALR, BLEZ, BGEZ, BLTZ, SLLV, SRLV, SRAV, SLT, SRA

wire   [5:0] opcode, funct, aluop;
assign opcode = instruction[31:26];
assign shamt = instruction[10:6];       // 位移操作�?
assign funct = instruction[5:0];         

wire r1_type = (opcode == SPECIAL);
assign r_type = r1_type;      
assign i_type = (opcode != J) && (opcode != JAL) && (!r1_type) ; 
assign j_type = (opcode == J) || (opcode == JAL); 
assign aluop = r_type ? funct : opcode;

assign gpr_wid = r_type ? instruction[15:11] : (i_type ? instruction[20:16] :
                                        (aluop == JAL) ? 5'b11111 : 5'b0); //写寄存器选择id

//-------------------------------------------- I-type ---------------------------------------------//
wire [15:0] imm = instruction[15:0];
wire [31:0] imm_ext_l, imm_ext_h;
assign imm_ext_l = (aluop == ANDI || aluop == ORI) ? {16'b0, imm} : {{16{imm[15]}}, imm}; 
assign imm_ext_h = {imm, 16'b0};        //op: LUI
assign imme = (aluop == LUI) ? imm_ext_h : imm_ext_l;  

assign s_lw = aluop == LW | aluop == LB ;             // 读内存�?�择
assign mem_write = aluop == SW | aluop == SB;             // 写内存�?�择
assign s_byte = aluop == SB | aluop == LB;

//-------------------------------------------- J-type ---------------------------------------------//
reg  [1:0]   s_pc;

always@(*) begin
    {s_pc, s_jal} = 3'b0; // 默认PC+4
    case(opcode)
        SPECIAL: begin
            case(funct)
                JR:  s_pc = 2'b10;  // 跳转到寄存器
            endcase
        end
        J:    s_pc = 2'b01; // 跳转到立即数
        JAL: {s_pc, s_jal} = {2'b01, 1'b1}; // 跳转到立即数并链�?
        BEQ:  s_pc = (a_reg == b_reg) ? 2'b11 : 2'b00;  // 分支等于
        BNE:  s_pc = (a_reg != b_reg) ? 2'b11 : 2'b00;  // 分支不等�?
        BGTZ: s_pc = ($signed(a_reg) >  0) ? 2'b11 : 2'b00;  
    endcase
end

wire [31:0]  pc_j, pc_b;
wire [31:0] imm_ext_branch = {{14{imm[15]}}, imm, 2'b0};    // 符号扩展后左�?2�?

assign pc_j = {pc[31:28], instruction[25:0], 2'b0};
assign pc_b = pc_4 + imm_ext_branch;

assign npc = (s_pc == 2'b01) ? pc_j : (s_pc == 2'b10) ? a_reg 
                                    : (s_pc == 2'b11) ? pc_b : 32'b0;   // 下一个PC�?, 不跳转则不设�?
assign s_pc_cal = |s_pc;                                     // 跳转成立
assign s_b_a = i_type && (aluop == BEQ || aluop == BNE || aluop == BGTZ ) || r1_type && (aluop == JR);  
assign s_b_b = i_type && (aluop == BEQ || aluop == BNE);

//-------------------------------------------- 写操作使�? -------------------------------------------//
assign reg_write =((r1_type && (aluop == ADD  || aluop == ADDU || aluop == SUB  || aluop == SLL  
                             || aluop == SRL  || aluop == AND  || aluop == XOR  || aluop == OR))
                || (j_type && (aluop == JAL)) ||
                   (i_type  && (aluop == ORI  || aluop == ANDI || aluop == XORI || aluop == LUI  
            || aluop == LW   || aluop == LB   || aluop == ADDI || aluop == ADDIU)) )  && (|gpr_wid);

assign s_quick =  ((r1_type && (aluop == ADD  || aluop == ADDU || aluop == SUB || aluop == SLL  
                             || aluop == SRL  || aluop == AND  || aluop == XOR  || aluop == OR))||
                   (j_type && (aluop == JAL)) ||
                   (i_type &&  (aluop == ORI  || aluop == ANDI || aluop == XORI || aluop == LUI  
            || aluop == ADDI || aluop == ADDIU)) )  && (|gpr_wid);

//------------------------------------- alu译码, 访存地址单独处理 ------------------------------------//
assign d_aluop  [0] =  i_type && (aluop == LUI);
assign d_aluop  [1] = r1_type && (aluop == ADDU || aluop == ADD) 
                    || i_type && (aluop == ADDI || aluop == ADDIU);
assign d_aluop  [2] = r1_type && (aluop == SUB);
assign d_aluop  [3] = r1_type && (aluop == AND) || (i_type && aluop == ANDI);
assign d_aluop  [4] = r1_type && (aluop == OR)  || (i_type && aluop == ORI);
assign d_aluop  [5] = r1_type && (aluop == XOR) || (i_type && aluop == XORI);
assign d_aluop  [6] = r1_type && (aluop == SLL);
assign d_aluop  [7] = r1_type && (aluop == SRL);


endmodule
