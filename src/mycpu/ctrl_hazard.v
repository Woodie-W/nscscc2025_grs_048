module ctrl_hazard(
    output wire [31:0]  pre_ar, pre_br, pre_wb_a, pre_wb_b, 
    output wire         fw_ar, fw_br, fw_wb_a, fw_wb_b,  // 前递
    output wire         pc_write, IF_ID_write, ID_EX1_write,
    output wire         EX1_EX2_flush, ID_EX1_flush,        // 阻塞信号

    input  wire [4:0]   rs, rt, rs_3, rt_3, gpr_wid_3, 
    input  wire         mem_write_2, mem_write_3, r_type, j_type, r_type_3, j_type_3,    // 需求信息

    input  wire [31:0]  gpr_in_4, gpr_in_5, gpr_in_6, gpr_in, gpr_in_4_ed,   // 冲突信息
    input  wire [4:0]   gpr_wid_4, gpr_wid_5, gpr_wid_6, gpr_wid,
    input  wire         s_lw_4, s_lw_5, s_lw_6, s_b_a, s_b_b, i_miss, ram_busy,
    input  wire         reg_write_3, reg_write_4, reg_write_5, reg_write_6, reg_write
);

    wire [4:0] a_in_id, b_in_id, a_r_id, b_r_id, rs_rin, rt_rin;  // rs_rin,rt_in为ID_EX1流水线寄存器输出
    wire ok_a, ok_b, ok_ar, ok_br, ok_arin, ok_brin;
    assign {ok_a, ok_b, ok_ar, ok_br, ok_arin, ok_brin} = {|a_in_id, |b_in_id, |rs, |rt, |rs_rin, |rt_rin};
    assign a_r_id = j_type ? 0 : rs;
    assign b_r_id = r_type | mem_write_2 ? rt : 0;
    assign a_in_id = j_type_3 ? 0 : rs_3;
    assign b_in_id = r_type_3 | mem_write_3 ? rt_3 : 0;
   
    assign rs_rin = ID_EX1_write ? a_r_id : a_in_id;
    assign rt_rin = ID_EX1_write ? b_r_id : b_in_id;
    
// ---------------------------------------------------------
// stall 优先顺序: rst -> !write -> flush -> write
// ---------------------------------------------------------
    wire stall_2, stall_3; //ID阻塞,EX1及后继续;EX1阻塞,EX2及后继续;stall_4为mul阻塞

    assign pc_write      = 1 ^ (stall_2 | stall_3);

    assign IF_ID_write   = 1 ^ (stall_2 | stall_3);
    
    assign ID_EX1_write  = 1 ^ stall_3; 
    assign ID_EX1_flush  = stall_2;  // 先判write 再判flush, 保证2级暂停的时候 为flush
    
    assign EX1_EX2_flush = stall_3;
    
    assign stall_3 = ram_busy ||  
            s_lw_4 && (gpr_wid_4 == rs_3 && ok_a || gpr_wid_4 == rs && ok_ar && s_b_a  
                    || gpr_wid_4 == rt_3 && ok_b || gpr_wid_4 == rt && ok_br && s_b_b) ||
            s_lw_5 && (gpr_wid_5 == rs_3 && ok_a || gpr_wid_5 == rs && ok_ar && s_b_a  
                    || gpr_wid_5 == rt_3 && ok_b || gpr_wid_5 == rt && ok_br && s_b_b) || 
            s_lw_6 && (gpr_wid_6 == rs_3 && ok_a || gpr_wid_6 == rs && ok_ar && s_b_a  
                    || gpr_wid_6 == rt_3 && ok_b || gpr_wid_6 == rt && ok_br && s_b_b);

    assign stall_2 = reg_write_3 && (rs == gpr_wid_3 && ok_ar && s_b_a 
                || ok_br && s_b_b && rt == gpr_wid_3) || i_miss;

// ---------------------------------------------------------
// forward ID/EX1 reg 流水线寄存器前递(before reg)
// ---------------------------------------------------------
    wire fw_wb_a_4 = reg_write_4 && (rs_rin == gpr_wid_4);
    wire fw_wb_b_4 = reg_write_4 && (rt_rin == gpr_wid_4);
    wire fw_wb_a_5 = reg_write_5 && (rs_rin == gpr_wid_5);
    wire fw_wb_b_5 = reg_write_5 && (rt_rin == gpr_wid_5);
    wire fw_wb_a_6 = reg_write && (rs_rin == gpr_wid);
    wire fw_wb_b_6 = reg_write && (rt_rin == gpr_wid);
    assign {fw_wb_a, fw_wb_b} = {fw_wb_a_4, fw_wb_b_4} | {fw_wb_a_5, fw_wb_b_5} | {fw_wb_a_6, fw_wb_b_6};

    assign pre_wb_a = fw_wb_a_4 ? gpr_in_4_ed : fw_wb_a_5 ? gpr_in_5 : gpr_in;
    assign pre_wb_b = fw_wb_b_4 ? gpr_in_4_ed : fw_wb_b_5 ? gpr_in_5 : gpr_in;
    
// ---------------------------------------------------------
// forward ID_branch 跳转判断用前递
// ---------------------------------------------------------
    wire fw_ar_4 = reg_write_4 && (rs == gpr_wid_4);
    wire fw_br_4 = reg_write_4 && (rt == gpr_wid_4);
    wire fw_ar_5 = reg_write_5 && (rs == gpr_wid_5);
    wire fw_br_5 = reg_write_5 && (rt == gpr_wid_5);
    wire fw_ar_6 = reg_write_6 && (rs == gpr_wid_6);
    wire fw_br_6 = reg_write_6 && (rt == gpr_wid_6);

    assign {fw_ar, fw_br} = {fw_ar_4, fw_br_4} | {fw_ar_5, fw_br_5} | {fw_ar_6, fw_br_6};
    assign pre_ar = fw_ar_4 ? gpr_in_4 : fw_ar_5 ? gpr_in_5 : gpr_in_6;
    assign pre_br = fw_br_4 ? gpr_in_4 : fw_br_5 ? gpr_in_5 : gpr_in_6;

endmodule
