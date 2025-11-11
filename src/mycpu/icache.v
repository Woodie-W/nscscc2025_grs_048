module icache(
    input  wire clk, rst, 

    input  wire [31:0]  npc,
    input  wire         pc_write, ram_hazard, mem_e_3_inst, // base ram结构冲突, EX1准备发射访存请求
    output wire [31:0]  instruction, 
    output wire         i_miss, 

    input  wire [31:0]  base_ram_out, 
    output reg  [31:0]  base_ram_ask    
);

wire [31:0] instruction_out, ipc;
reg  [31:0] pc_reg, pre_ipc;
always@(posedge clk) begin
    if(rst) begin
        pc_reg <= 32'h8000_0000; pre_ipc <= 32'h8000_0000;
    end else begin
        pc_reg <= pc_write ? npc : pc_reg; pre_ipc <= ipc;
    end
end

assign instruction = instruction_out;
assign ipc = pc_write ? npc : pc_reg;

// ---------------------------------------------------------
// block ram 控制信号与实例化  (两路组相联; 每路1个TAGV,共2个; 每路4个DATA BANK,共8个)
// ---------------------------------------------------------
wire [9:0]  tag     = ipc[21:12];    // tag(10位)
wire [7:0]  index   = ipc[11:4];     // index(256组)
wire [1:0]  offset  = ipc[3:2];      // 行内偏移(16字节行)
wire [9:0]  pre_tag = pre_ipc[21:12];
wire [1:0]  pre_ipc_offset = pre_ipc[3:2];
// BlockRAM 信号
wire [10:0] tagv_out [1:0];         // 两个TAGV RAM的输出
wire [31:0] bank_out [1:0][3:0];    // 两路×四组 输出
reg  [1:0]  tagv_ena_reg, bank_ena_reg, fill_offset_reg; 
wire [1:0]  n_fill_offset = fill_offset_reg + 1;
reg  [7:0]  fill_index_reg;

genvar way;
generate
    for (way = 0; way < 2; way = way + 1) begin : tagv_rams
        blk_cache_TAGV tagv_ram (
            .clka(clk), .wea(1'b1), .ena(tagv_ena_reg[way]),  // a端口inout, b端口out
            .addra(fill_index_reg), .dina({1'b1, tag}), // 不存在写入v=0
            .clkb(clk), .addrb(index), .doutb(tagv_out[way])  
        );
    end
endgenerate

genvar way_idx, bank_idx;
generate
    for (way_idx = 0; way_idx < 2; way_idx = way_idx + 1) begin : way_banks
        for (bank_idx = 0; bank_idx < 4; bank_idx = bank_idx + 1) begin : data_banks
            wire ena = (fill_offset_reg == bank_idx) & bank_ena_reg[way_idx];
            blk_cache_BANK bank_ram (
                .clka(clk), .wea(1'b1), .ena(ena),
                .addra(fill_index_reg), .dina(base_ram_out),
                .clkb(clk), .addrb(index), .doutb(bank_out[way_idx][bank_idx])  
            );
        end
    end
endgenerate

// ---------------------------------------------------------
// 控制逻辑
// ---------------------------------------------------------
wire [31:0] way0_data = bank_out[0][pre_ipc_offset];
wire [31:0] way1_data = bank_out[1][pre_ipc_offset];
wire        way0_v = tagv_out[0][10]; 
wire        way1_v = tagv_out[1][10];
wire [9:0]  way0_tag = tagv_out[0][9:0];
wire [9:0]  way1_tag = tagv_out[1][9:0];

wire way0_hit = way0_v && (way0_tag == pre_tag);
wire way1_hit = way1_v && (way1_tag == pre_tag);
wire cache_hit = way0_hit || way1_hit;

assign instruction_out = ({32{way0_hit}} & way0_data | {32{way1_hit}} & way1_data); 

reg    i_stall;
assign i_miss = !cache_hit | i_stall;

// --------------------------------------------------------
// 状态机:  Look up,如果命中保存此状态不变; 
// 如果未命中 -> refill装填ichche,装填一个路的每个数据;
// 装填结束后回到Look up, 
// --------------------------------------------------------
localparam  S_LOOKUP    = 2'b00;        // 查找状态(默认状态)
localparam  S_REFILL    = 2'b01;        // 填充状态
localparam  S_MEM_BASE  = 2'b11;        // 写baseram结构冲突

reg  [3:0]  cunter;
reg  [1:0]  state, way_chosen_reg;
wire [1:0]  way_chosen = ipc[12] ? 2'b01 : 2'b10;

always @(posedge clk) begin
    if (rst) begin
        state <= S_LOOKUP; cunter <= 0; base_ram_ask <= 0; fill_index_reg <= 0;
        tagv_ena_reg <= 2'b0; bank_ena_reg <= 2'b0; fill_offset_reg <= 2'b0;
    end else begin
        case (state)
            S_LOOKUP: begin   // LOOKUP状态: 每个周期都在此状态检查命中情况 
                bank_ena_reg <= 0; way_chosen_reg <= 0; tagv_ena_reg <= 0;
                cunter <= 0; base_ram_ask <= 0; 
                if (i_miss) begin   // 未命中，启动填充流程
                    state <= S_REFILL; fill_offset_reg <= offset; fill_index_reg <= index;
                    base_ram_ask <= {ipc[31:4], offset, 2'b00}; // 对齐行首地址
                    i_stall <= 1; way_chosen_reg <= way_chosen;
                    if(ram_hazard) state <= S_LOOKUP;
                end
            end
            
            S_REFILL: begin  // REFILL状态: 并行执行数据填充和TAG更新
                if (ram_hazard) begin 
                    state <= S_LOOKUP; i_stall <= 1;
                end else if (cunter == 0) begin
                    bank_ena_reg <= way_chosen_reg; tagv_ena_reg <= way_chosen_reg; // 选择替换路 
                end else if (cunter == 2) begin
                    base_ram_ask <= {ipc[31:4], n_fill_offset, 2'b00}; 
                end else if(cunter == 3) begin
                    fill_offset_reg <= n_fill_offset; tagv_ena_reg <= 2'b0;
                end else if (cunter == 5) begin
                    base_ram_ask <= {ipc[31:4], n_fill_offset, 2'b00};
                end else if(cunter == 6) begin
                    fill_offset_reg <= n_fill_offset; 
                end else if(cunter == 8) begin
                    base_ram_ask <= {ipc[31:4], n_fill_offset, 2'b00}; 
                end else if(cunter == 9) begin
                    fill_offset_reg <= n_fill_offset; 
                end else if(cunter == 10) begin
                    i_stall <= mem_e_3_inst ? 1 : 0;
                end else if(cunter == 11) begin
                    base_ram_ask <= 32'b0; state <= S_LOOKUP; i_stall <= 0;
                end 
                cunter <= cunter+1;
            end
        endcase
    end
end

endmodule
