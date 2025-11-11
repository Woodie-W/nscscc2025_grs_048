module ddd_cpu(
    input   wire		    clk,
	input   wire		    rst,

    //连接指令存储器base_ram, 组合读写
	output  wire[31:0]      base_ram_ask, 
	input   wire[31:0]      base_ram_out,   
	
	//连接数据存储器ext_ram, EX1接入,时序读请求,组合返回
	input   wire [31:0]     mem_out,    //得到的数据
    output  wire [31:0]     address,    //写/读地址
	output  wire [31:0]     data_sw,    //写入的数据
    output  wire [3:0]      s_ram_in,   //高写,全0读
    output  wire            mem_e,      //存储器使能,高有效
    output  wire            mem_write   //存储器写使能,高有效
);

// pc, instruction
wire [31:0]     pc, npc, pc_8, pc_cal, instruction, pc_4_1;
// ctrl
wire            r_type, i_type, j_type, s_lw, mem_write_2;
wire            s_byte, s_jal, s_pc_cal, s_b_a, s_b_b, s_quick;
wire [4:0]      shamt;          // 位移立即数
// gpr
wire            reg_write;      // reg写使能
wire [31:0]     a_reg, b_reg, a_reg_2, b_reg_2, gpr_in_4_ed, gpr_in_6;
wire [4:0]      rs, rt, gpr_wid;    // gpr_wid 来自第五级
reg  [4:0]      gpr_wid_4, gpr_wid_5, gpr_wid_6;
reg             reg_write_4, reg_write_5, reg_write_6;
// alu & dm & ram_serial
wire [7:0]      d_aluop;
wire [31:0]     a, b, c, c1, data_sw_3, gpr_in_3, address_3, imme; // c == address_3
reg  [31:0]     address_4, address_5, data_sw_4, data_sw_5, gpr_in_4, gpr_in_5, mem_out_6, c_6;
reg             mem_e_4_i, mem_e_5, mem_write_3, mem_write_4, mem_write_5, s_lw_4, s_lw_5, s_lw_6;

wire            i_miss, base_ram_e, mem_e_3_inst, mem_e_3, is_serial_4, mem_e_4;
wire [3:0]      s_ram_3, s_ram_out, s_ram_in_3;
reg  [3:0]      s_ram_in_4, s_ram_in_5, s_ram_out_4, s_ram_out_5, s_ram_out_6;

assign mem_e_4 = mem_e_4_i && ~is_serial_4;
assign mem_e = mem_e_3 | mem_e_4 | mem_e_5;
assign address = mem_e_5 ? address_5 : mem_e_4 ? address_4 : address_3;
assign data_sw = mem_e_5 ? data_sw_5 : mem_e_4 ? data_sw_4 : data_sw_3;
assign s_ram_in = mem_e_5 ? s_ram_in_5 : mem_e_4 ? s_ram_in_4 : s_ram_in_3;
assign mem_write = mem_e_5 ? mem_write_5 : mem_e_4 ? mem_write_4 : mem_write_3;

// forward
wire            fw_ar, fw_br, fw_wb_a, fw_wb_b;  // 旁路
wire [31:0]     pre_ar, pre_br, pre_wb_a, pre_wb_b;    // 前递数据
reg  [31:0]     pre_c;
// stall
wire            IF_ID_write, ID_EX1_write, EX1_EX2_flush, ID_EX1_flush;
wire            pc_write, ram_busy, ram_hazard, ram_hazard_3;
reg             fw_b, fw_a, fw_sw, ram_hazard_4, ram_hazard_5;
assign ram_hazard = ram_hazard_3 | ram_hazard_4 | ram_hazard_5;
assign ram_busy = mem_e_3_inst && (mem_e_4 | mem_e_5);
// ---------------------------------------------------------
// 1. IF Instruction Fetch
// ---------------------------------------------------------
assign npc = s_pc_cal ? pc_cal : pc+4;
assign pc_4_1 = pc + 32'd4;
pc PC(          .clk(clk), .rst(rst), .pc_write(pc_write), .npc(npc),   // in
                .pc(pc)             // out    
);                                  // PC寄存器

icache I_CACHE( .clk(clk), .rst(rst), .pc_write(pc_write), .npc(npc), .instruction(instruction), 
                .base_ram_out(base_ram_out), .base_ram_ask(base_ram_ask), .i_miss(i_miss),
                .ram_hazard(ram_hazard), .mem_e_3_inst(mem_e_3_inst)
);                                  // 指令缓存

// ---------------------------------------------------------
// IF/ID Pipeline Register && 2. ID Stage: Instruction Decode
// ---------------------------------------------------------
reg  [31:0]     instruction_2, instruction_pre, pc_2, pc_4_2; parameter pc_init = 32'h8000_0000;
always @(posedge clk) begin
    if (rst) begin
        instruction_pre <= 0; instruction_2 <= 0; pc_4_2 <= pc_4_1; pc_2 <= pc_init;
    end else if(!IF_ID_write) begin
        pc_2 <= pc_2; instruction_2 <= instruction_2; pc_4_2 <= pc_4_2;
    end else begin
        pc_2 <= pc; instruction_2 <= instruction; pc_4_2 <= pc_4_1;
    end
end

assign rs = instruction_2[25:21];
assign rt = instruction_2[20:16];
assign a_reg_2 = fw_ar ? pre_ar : a_reg;
assign b_reg_2 = fw_br ? pre_br : b_reg;
assign pc_8 = pc_2 + 32'd8;

gpr GPR(        .clk(clk), .rst(rst), .rs(instruction[25:21]), .rt(instruction[20:16]),
                .num_write(gpr_wid_6), .data_write(gpr_in_6), .reg_write(reg_write_6),  
                .a(a_reg), .b(b_reg), .IF_ID_write(IF_ID_write)
);

ctrl_decode CTRL_DECODE(      
                .instruction(instruction_2), .d_aluop(d_aluop),
                .gpr_wid(gpr_wid), .reg_write(reg_write), .imme(imme), .shamt(shamt), 
                .r_type(r_type), .i_type(i_type), .j_type(j_type),
                
                .s_lw(s_lw), .mem_write(mem_write_2), .s_byte(s_byte), .s_quick(s_quick),   //访存
                .s_pc_cal(s_pc_cal), .s_jal(s_jal), .s_b_a(s_b_a), .s_b_b(s_b_b),
                .pc(pc_2), .pc_4(pc_4_2), .npc(pc_cal), .a_reg(a_reg_2), .b_reg(b_reg_2)    //跳转
);

// ---------------------------------------------------------
// ID/EX Pipeline Register && 3. EX1 Stage: Execute1 && Pre DM (用于预处理存数和字节使能)
// ---------------------------------------------------------
reg [31:0] a_reg_3, b_reg_3, pc_8_3, imme_3, mem_out_wb;
reg [7:0]  d_aluop_3;
reg [4:0]  shamt_3, gpr_wid_3, rs_3, rt_3;  
reg        i_type_3, s_jal_3, s_lw_3, reg_write_3, r_type_3, j_type_3, s_byte_3, s_quick_3;
always @(posedge clk) begin
    if(rst) begin
        pc_8_3 <= 0; a_reg_3 <= 0; b_reg_3 <= 0; imme_3 <= 0; d_aluop_3 <= 0; shamt_3 <= 0;
        i_type_3 <= 0; mem_write_3 <= 0; s_jal_3 <= 0; s_lw_3 <= 0; reg_write_3 <= 0;  gpr_wid_3 <= 0; 
        r_type_3 <= 0; j_type_3 <= 0; rs_3 <= 0; rt_3 <= 0; fw_a <= 0; fw_b <= 0; fw_sw <= 0; pre_c <= 0;
        s_quick_3 <= 0; s_byte_3 <= 0;
    end else if(!ID_EX1_write) begin
        pc_8_3 <= pc_8_3; d_aluop_3 <= d_aluop_3; shamt_3 <= shamt_3; rs_3 <= rs_3; 
        rt_3 <= rt_3;  i_type_3 <= i_type_3; mem_write_3 <= mem_write_3; s_jal_3 <= s_jal_3; s_lw_3 <= s_lw_3; 
        s_byte_3 <= s_byte_3; reg_write_3 <= reg_write_3; r_type_3 <= r_type_3; j_type_3 <= j_type_3; 
        gpr_wid_3 <= gpr_wid_3; s_quick_3 <= s_quick_3; imme_3 <= imme_3; 
        a_reg_3 <= fw_wb_a ? pre_wb_a : a_reg_3; b_reg_3 <= fw_wb_b ? pre_wb_b : b_reg_3; 
        fw_a <= fw_a; fw_b <= fw_b; fw_sw <= fw_sw; 
    end else if(ID_EX1_flush) begin
        pc_8_3 <= 0; d_aluop_3 <= 0; shamt_3 <= 0; a_reg_3 <= 0; b_reg_3 <= 0; imme_3 <= 0;
        i_type_3 <= 0; mem_write_3 <= 0; s_jal_3 <= 0; s_lw_3 <= 0; reg_write_3 <= 0; gpr_wid_3 <= 0; 
        r_type_3 <= 0; j_type_3 <= 0; rs_3 <= 0; rt_3 <= 0; fw_a <= 0; fw_b <= 0; fw_sw <= 0;
        s_quick_3 <= 0; s_byte_3 <= 0;
    end else begin
        pc_8_3 <= pc_8; d_aluop_3 <= d_aluop; shamt_3 <= shamt; rs_3 <= rs; rt_3 <= rt; 
        i_type_3 <= i_type; mem_write_3 <= mem_write_2; s_jal_3 <= s_jal; s_lw_3 <= s_lw; s_byte_3 <= s_byte;
        reg_write_3 <= reg_write; r_type_3 <= r_type; j_type_3 <= j_type;
        gpr_wid_3 <= gpr_wid; s_quick_3 <= s_quick; pre_c <= gpr_in_3; imme_3 <= imme; 
        a_reg_3 <= fw_wb_a ? pre_wb_a : a_reg_2; b_reg_3 <= fw_wb_b ? pre_wb_b : b_reg_2; 
        fw_a <= ID_EX1_write && !j_type && rs == gpr_wid_3 && reg_write_3 && s_quick_3;
        fw_b <= ID_EX1_write &&  r_type && rt == gpr_wid_3 && reg_write_3 && s_quick_3;
        fw_sw <= ID_EX1_write && mem_write_2 && rt == gpr_wid_3 && reg_write_3 && s_quick_3; 
    end
end

assign a = fw_a ? pre_c : a_reg_3; // ALU输入a选择
assign b = i_type_3 ? imme_3 : fw_b ? pre_c : b_reg_3; // ALU输入b选择
alu ALU( .a(a), .b(b), .c(c), .d_aluop(d_aluop_3), .shamt(shamt_3));
assign gpr_in_3 = s_jal_3 ? pc_8_3 : c;

assign data_sw_3 = fw_sw ? pre_c : b_reg_3;   // 存内存选择
assign address_3 = a + b;
wire [1:0] lowbit = a[1:0] + b[1:0];
assign mem_e_3_inst = (s_lw_3 | mem_write_3);
assign mem_e_3 = mem_e_3_inst & ~EX1_EX2_flush;   //存储器使能高有效
assign s_ram_3 = (4'b0001 << lowbit) | {4{~s_byte_3}};      //字节选择高有效
assign s_ram_in_3 = s_ram_3 & {4{mem_write_3}};   //高有效写, 全0读
assign s_ram_out = s_ram_3 & {4{s_lw_3}};       //高读, 用于处理读到的数
assign ram_hazard_3 = address_3 >= 32'h8000_0000 && address_3 <= 32'h803fffff && mem_e_3;   //存储器结构冒险
// ---------------------------------------------------------
// EX1/EX2 Pipeline Register && 4. EX2 Stage: Execute2 && Memory Access1
// ---------------------------------------------------------       
always @(posedge clk) begin
    if (rst | EX1_EX2_flush) begin
        reg_write_4 <= 0; gpr_wid_4 <= 0; address_4 <= 0; gpr_in_4 <= 0;
        s_lw_4 <= 0; s_ram_out_4 <= 0; ram_hazard_4 <= 0;
        data_sw_4 <= 0; s_ram_in_4 <= 0; mem_write_4 <= 0; mem_e_4_i <= 0; 
    end else begin
        reg_write_4 <= reg_write_3; gpr_wid_4 <= gpr_wid_3; address_4 <= address_3; gpr_in_4 <= gpr_in_3;
        s_lw_4 <= s_lw_3; s_ram_out_4 <= s_ram_out; ram_hazard_4 <= ram_hazard_3;
        data_sw_4 <= data_sw_3; s_ram_in_4 <= s_ram_in_3; mem_write_4 <= mem_write_3; mem_e_4_i <= mem_e_3;
    end
end

assign is_serial_4 = (address_4 == 32'hbfd0_03fc || address_4 == 32'hbfd0_03f8) && mem_e_4_i; //串口
assign gpr_in_4_ed = is_serial_4 ? mem_out : gpr_in_4;    //存寄存器选择

// ---------------------------------------------------------
// EX2/EX3 Pipeline Register && 5. EX3 Stage: Memory Access2 && Get Byte
// ---------------------------------------------------------
always @(posedge clk) begin
    if (rst) begin
        s_lw_5 <= 0; mem_write_5 <= 0; address_5 <= 0; s_ram_in_5 <= 0; 
        s_ram_out_5 <= 0; gpr_in_5 <= 0; ram_hazard_5 <= 0; data_sw_5 <= 0;
        reg_write_5 <= 0; gpr_wid_5 <= 0; mem_e_5 <= 0; 
    end else begin
        s_lw_5 <= is_serial_4 ? 0 : s_lw_4; mem_write_5 <= is_serial_4 ? 0 : mem_write_4;
        address_5 <= address_4; s_ram_in_5 <= s_ram_in_4; s_ram_out_5 <= s_ram_out_4; 
        gpr_in_5 <= gpr_in_4_ed; ram_hazard_5 <= ram_hazard_4; data_sw_5 <= data_sw_4;
        reg_write_5 <= reg_write_4; gpr_wid_5 <= gpr_wid_4; mem_e_5 <= mem_e_4; 
    end
end

// ---------------------------------------------------------
// EX3/EX4 Pipeline Register && 6. EX4 & pre WB 
// ---------------------------------------------------------
always @(posedge clk) begin
    if (rst) begin
        c_6 <= 0; s_lw_6 <= 0; s_ram_out_6 <= 0;
        reg_write_6 <= 0; gpr_wid_6 <= 0;
    end else begin
        c_6 <= gpr_in_5; s_lw_6 <= s_lw_5; s_ram_out_6 <= s_ram_out_5;
        reg_write_6 <= reg_write_5; gpr_wid_6 <= gpr_wid_5;
    end
end

always @(*) begin
    case(s_ram_out_6)
        4'b1111: mem_out_6 = mem_out;
        4'b0001: mem_out_6 = {{24{mem_out[7]}}, mem_out[7:0]};
        4'b0010: mem_out_6 = {{24{mem_out[15]}}, mem_out[15:8]};
        4'b0100: mem_out_6 = {{24{mem_out[23]}}, mem_out[23:16]}; 
        4'b1000: mem_out_6 = {{24{mem_out[31]}}, mem_out[31:24]};
        default: mem_out_6 = 32'b0; // 其他情况, 不可能 
    endcase    
end

assign gpr_in_6 = s_lw_6 ? mem_out_6 : c_6;  

// ---------------------------------------------------------
// Ctrl_Hazard
// ---------------------------------------------------------
ctrl_hazard Ctrl_HAZARD(
                .pre_ar(pre_ar), .pre_br(pre_br), .fw_ar(fw_ar), .fw_br(fw_br), 
                .fw_wb_a(fw_wb_a), .fw_wb_b(fw_wb_b), .pre_wb_a(pre_wb_a), .pre_wb_b(pre_wb_b),
                
                .pc_write(pc_write), .IF_ID_write(IF_ID_write), .ID_EX1_write(ID_EX1_write), 
                .EX1_EX2_flush(EX1_EX2_flush), .ID_EX1_flush(ID_EX1_flush), .i_miss(i_miss),

                .reg_write_3(reg_write_3), .mem_write_2(mem_write_2), .mem_write_3(mem_write_3),
                .r_type(r_type), .j_type(j_type), .r_type_3(r_type_3), .j_type_3(j_type_3), 
                .rs(rs), .rt(rt), .rs_3(rs_3), .rt_3(rt_3), .gpr_wid_3(gpr_wid_3),
                
                .gpr_wid_4(gpr_wid_4), .gpr_in_4(gpr_in_4), .reg_write_4(reg_write_4),
                .gpr_wid_5(gpr_wid_5), .gpr_in_5(gpr_in_5), .reg_write_5(reg_write_5),
                .gpr_wid_6(gpr_wid_6), .gpr_in_6(c_6), .reg_write_6(reg_write_6),
                .gpr_wid(gpr_wid_6), .gpr_in(gpr_in_6), .reg_write(reg_write_6),
                .s_lw_4(s_lw_4), .s_lw_5(s_lw_5), .s_lw_6(s_lw_6),
                .s_b_a(s_b_a), .s_b_b(s_b_b), .gpr_in_4_ed(gpr_in_4_ed), .ram_busy(ram_busy)
);

endmodule
