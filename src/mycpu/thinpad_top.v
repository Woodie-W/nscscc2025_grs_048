`default_nettype none

module thinpad_top(
    input  wire         clk_50M,        //50MHz 时钟输入
    input  wire         clk_11M0592,    //11.0592MHz 时钟输入（备用，可不用）
    input  wire         clock_btn,      //BTN5手动时钟按钮开关，带消抖电路，按下时为1
    input  wire         reset_btn,      //BTN6手动复位按钮开关，带消抖电路，按下时为1

    input  wire [3:0]   touch_btn,      //BTN1~BTN4，按钮开关，按下时为1
    input  wire [31:0]  dip_sw,         //32位拨码开关，拨到“ON”时为1
    output wire [15:0]  leds,           //16位LED，输出时1点亮
    output wire [7:0]   dpy0,           //数码管低位信号，包括小数点，输出1点亮
    output wire [7:0]   dpy1,           //数码管高位信号，包括小数点，输出1点亮

    //BaseRAM信号
    inout  wire [31:0]  base_ram_data,  //BaseRAM数据，低8位与CPLD串口控制器共享
    output wire [19:0]  base_ram_addr,  //BaseRAM地址
    output wire [3:0]   base_ram_be_n,  //BaseRAM字节使能，低有效。如果不使用字节使能，请保持为0
    output wire         base_ram_ce_n,  //BaseRAM片选，低有效
    output wire         base_ram_oe_n,  //BaseRAM读使能，低有效
    output wire         base_ram_we_n,  //BaseRAM写使能，低有效

    //ExtRAM信号
    inout  wire [31:0]  ext_ram_data,   //ExtRAM数据
    output wire [19:0]  ext_ram_addr,   //ExtRAM地址
    output wire [3:0]   ext_ram_be_n,   //ExtRAM字节使能，低有效。如果不使用字节使能，请保持为0
    output wire         ext_ram_ce_n,   //ExtRAM片选，低有效
    output wire         ext_ram_oe_n,   //ExtRAM读使能，低有效
    output wire         ext_ram_we_n,   //ExtRAM写使能，低有效

    //直连串口信号
    output wire         txd,            //直连串口发送端
    input  wire         rxd,            //直连串口接收端

    //Flash存储器信号，参考 JS28F640 芯片手册
    output wire [22:0]  flash_a,        //Flash地址，a0仅在8bit模式有效，16bit模式无意义
    inout  wire [15:0]  flash_d,        //Flash数据
    output wire         flash_rp_n,     //Flash复位信号，低有效
    output wire         flash_vpen,     //Flash写保护信号，低电平时不能擦除、烧写
    output wire         flash_ce_n,     //Flash片选信号，低有效
    output wire         flash_oe_n,     //Flash读使能信号，低有效
    output wire         flash_we_n,     //Flash写使能信号，低有效
    output wire         flash_byte_n,   //Flash 8bit模式选择，低有效。在使用flash的16位模式时请设为1

    //图像输出信号
    output wire [2:0]   video_red,      //红色像素，3位
    output wire [2:0]   video_green,    //绿色像素，3位
    output wire [1:0]   video_blue,     //蓝色像素，2位
    output wire         video_hsync,    //行同步（水平同步）信号
    output wire         video_vsync,    //场同步（垂直同步）信号
    output wire         video_clk,      //像素时钟输出
    output wire         video_de        //行数据有效信号，用于区分消隐区
);

/* =========== Demo code begin =========== */

// PLL分频示例
wire locked, clk_10M, clk_in;
pll_example clock_gen (
    .clk_in1(clk_50M),      // 外部时钟输入
    .clk_out1(clk_10M),     // 时钟输出1,频率在IP配置界面中设置 // 已改成50
    .clk_out2(clk_in),      // 时钟输出2,频率在IP配置界面中设置
    .reset(reset_btn),      // PLL复位输入
    .locked(locked)         // PLL锁定指示输出,"1"表示时钟稳定，                  
 ); //后级电路复位信号应当由它生成(见下)

reg reset_of_clk;
// 异步复位，同步释放，将locked信号转为后级电路的复位reset_of_clk10M
always@(posedge clk_in or negedge locked) begin
    if(~locked) reset_of_clk <= 1'b1;
    else        reset_of_clk <= 1'b0;
end

//cpu data sram
wire        cpu_data_e;
wire        cpu_data_w;
wire [3:0]  cpu_data_we;
wire [31:0] cpu_data_addr;
wire [31:0] cpu_data_wdata;
reg  [31:0] cpu_data_rdata;
reg  [31:0] cpu_inst_rdata;

// cpu 里出来都是高位有效
wire [31:0] base_ram_ask, npc;
reg [31:0] pc;
ddd_cpu DDD_CPU(              
    .clk(clk_in), .rst(reset_of_clk),
    .base_ram_out(cpu_inst_rdata), .base_ram_ask(base_ram_ask),

    .mem_e(cpu_data_e), .mem_write(cpu_data_w), .s_ram_in(cpu_data_we),
    .address(cpu_data_addr), .data_sw(cpu_data_wdata), .mem_out(cpu_data_rdata)
);

parameter f_clk = 165_625_000;
parameter f_uart = 9600;

reg [31:0] base_ram_data_r;
reg [19:0] base_ram_addr_r;
reg [3:0] base_ram_be_n_r;
reg base_ram_ce_n_r;
reg base_ram_oe_n_r;
reg base_ram_we_n_r;

assign base_ram_data = base_ram_data_r;
assign base_ram_addr = base_ram_addr_r; 
assign base_ram_be_n = base_ram_be_n_r;
assign base_ram_ce_n = base_ram_ce_n_r;
assign base_ram_oe_n = base_ram_oe_n_r;
assign base_ram_we_n = base_ram_we_n_r;

reg [31:0] ext_ram_data_r;
reg [19:0] ext_ram_addr_r;
reg [3:0] ext_ram_be_n_r;
reg ext_ram_ce_n_r;
reg ext_ram_oe_n_r;
reg ext_ram_we_n_r;

assign ext_ram_data = ext_ram_data_r;
assign ext_ram_addr = ext_ram_addr_r;
assign ext_ram_be_n = ext_ram_be_n_r;
assign ext_ram_ce_n = ext_ram_ce_n_r;
assign ext_ram_oe_n = ext_ram_oe_n_r;
assign ext_ram_we_n = ext_ram_we_n_r;

wire [31:0] uart_rdata;
reg  [31:0] uart_wdata;
wire [7:0] ext_uart_rx;
reg  [7:0] ext_uart_buffer, ext_uart_tx;
wire ext_uart_ready, ext_uart_clear, ext_uart_busy;
reg  ext_uart_start, ext_uart_avai, cpu_data_avai;
reg  sel_inst;      // 1-inst 0-data for base_ram
reg  sel_uart;
reg  sel_uart_flag;     // 1-flag 0-data

// in 
always @ (*) begin
    if (reset_of_clk) begin  
        cpu_inst_rdata <= 32'b0;
        cpu_data_rdata <= 32'b0; 
    end else begin
        cpu_inst_rdata <= ~base_ram_oe_n_r ? base_ram_data : 32'b0;
        cpu_data_rdata <= sel_uart ? uart_rdata : sel_inst ? (~ext_ram_oe_n_r ? ext_ram_data : 32'b0) 
                                                            : (~base_ram_oe_n_r ? base_ram_data : 32'b0);
    end
end

assign uart_rdata = sel_uart_flag ? {30'b0,ext_uart_avai,~ext_uart_busy} : {24'b0,ext_uart_buffer};

// out 
always @ (posedge clk_in) begin
    if (reset_of_clk) begin
        base_ram_addr_r <= 19'b0;
        base_ram_be_n_r <= 4'b0;
        base_ram_ce_n_r <= 1'b1;
        base_ram_oe_n_r <= 1'b1;
        base_ram_we_n_r <= 1'b1;
        base_ram_data_r <= 32'b0;

        ext_ram_addr_r <= 19'b0;
        ext_ram_be_n_r <= 4'b0;
        ext_ram_ce_n_r <= 1'b1;
        ext_ram_oe_n_r <= 1'b1;
        ext_ram_we_n_r <= 1'b1;
        ext_ram_data_r <= 32'b0;

        sel_inst <= 1'b1;
        sel_uart <= 1'b0;
        sel_uart_flag <= 1'b0;
        uart_wdata <= 32'b0;
        cpu_data_avai <= 1'b0;
    end else if (cpu_data_addr >=32'h8000_0000 && cpu_data_addr <= 32'h803f_ffff && cpu_data_e) begin
        base_ram_addr_r <= cpu_data_addr[21:2];
        base_ram_be_n_r <= cpu_data_w ? ~cpu_data_we : 4'b0;
        base_ram_ce_n_r <= ~cpu_data_e;
        base_ram_oe_n_r <= ~cpu_data_e | cpu_data_w;
        base_ram_we_n_r <= ~(cpu_data_e & cpu_data_w);
        base_ram_data_r <= cpu_data_w ? cpu_data_wdata : 32'bz;

        ext_ram_addr_r <= 19'b0;
        ext_ram_be_n_r <= 4'b0;
        ext_ram_ce_n_r <= 1'b1;
        ext_ram_oe_n_r <= 1'b1;
        ext_ram_we_n_r <= 1'b1;  
        ext_ram_data_r <= 32'b0;

        sel_inst <= 1'b0;
        sel_uart <= 1'b0;
        sel_uart_flag <= 1'b0;
        uart_wdata <= 32'b0;
        cpu_data_avai <= 1'b0;
    end else if (cpu_data_addr >= 32'h8040_0000 && cpu_data_addr <= 32'h807fffff && cpu_data_e) begin   
        base_ram_addr_r <= base_ram_ask[21:2]; 
        base_ram_be_n_r <= 4'b0;
        base_ram_ce_n_r <= 1'b0;
        base_ram_oe_n_r <= 1'b0;
        base_ram_we_n_r <= 1'b1;
        base_ram_data_r <= 32'bz;

        ext_ram_addr_r <= cpu_data_addr[21:2];
        ext_ram_be_n_r <= cpu_data_w ? ~cpu_data_we : 4'b0;
        ext_ram_ce_n_r <= ~cpu_data_e;
        ext_ram_oe_n_r <= ~cpu_data_e | cpu_data_w;
        ext_ram_we_n_r <= ~(cpu_data_e & cpu_data_w); 
        ext_ram_data_r <= cpu_data_w ? cpu_data_wdata : 32'bz;

        sel_inst <= 1'b1;
        sel_uart <= 1'b0;
        sel_uart_flag <= 1'b0;
        uart_wdata <= 32'b0;
        cpu_data_avai <= 1'b0;
    end else if (cpu_data_addr == 32'hbfd0_03fc) begin
        base_ram_addr_r <= base_ram_ask[21:2]; 
        base_ram_be_n_r <= 4'b0;
        base_ram_ce_n_r <= 1'b0;
        base_ram_oe_n_r <= 1'b0;
        base_ram_we_n_r <= 1'b1;
        base_ram_data_r <= 32'bz;
      
        ext_ram_addr_r <= 19'b0;
        ext_ram_be_n_r <= 4'b0;
        ext_ram_ce_n_r <= 1'b1;
        ext_ram_oe_n_r <= 1'b1;
        ext_ram_we_n_r <= 1'b1;
        ext_ram_data_r <= 32'b0;

        sel_inst <= 1'b1;
        sel_uart <= 1'b1;
        sel_uart_flag <= 1'b1;
        uart_wdata <= 32'b0;
        cpu_data_avai <= 1'b0;
    end else if (cpu_data_addr == 32'hbfd0_03f8 && cpu_data_e) begin    
        base_ram_addr_r <= base_ram_ask[21:2];     
        base_ram_be_n_r <= 4'b0;
        base_ram_ce_n_r <= 1'b0;
        base_ram_oe_n_r <= 1'b0;
        base_ram_we_n_r <= 1'b1;
        base_ram_data_r <= 32'bz;
             
        ext_ram_addr_r <= 19'b0;
        ext_ram_be_n_r <= 4'b0;
        ext_ram_ce_n_r <= 1'b1;
        ext_ram_oe_n_r <= 1'b1;
        ext_ram_we_n_r <= 1'b1;
        ext_ram_data_r <= 32'b0;

        sel_inst <= 1'b1;
        sel_uart <= 1'b1;
        sel_uart_flag <= 1'b0;
        uart_wdata <= cpu_data_wdata;
        cpu_data_avai <= cpu_data_w ? 1'b1 : 1'b0;
    end else begin        
        base_ram_addr_r <= base_ram_ask[21:2]; 
        base_ram_be_n_r <= 4'b0;
        base_ram_ce_n_r <= 1'b0;
        base_ram_oe_n_r <= 1'b0;
        base_ram_we_n_r <= 1'b1;
        base_ram_data_r <= 32'bz;
      
        ext_ram_addr_r <= 19'b0;
        ext_ram_be_n_r <= 4'b0;
        ext_ram_ce_n_r <= 1'b1;
        ext_ram_oe_n_r <= 1'b1;
        ext_ram_we_n_r <= 1'b1;
        ext_ram_data_r <= 32'b0;

        sel_inst <= 1'b1;
        sel_uart <= 1'b0;
        sel_uart_flag <= 1'b0;
        uart_wdata <= 32'b0;
        cpu_data_avai <= 1'b0;
    end
end

// uart
async_receiver #(.ClkFrequency(f_clk),.Baud(f_uart)) //接收模块,9600无检验位
    ext_uart_r(
        .clk(clk_in),                       //外部时钟信号
        .RxD(rxd),                          //外部串行信号输入
        .RxD_data_ready(ext_uart_ready),    //数据接收到标志
        .RxD_clear(ext_uart_clear),         //清除接收标志
        .RxD_data(ext_uart_rx)              //接收到的一字节数据
    );

assign ext_uart_clear = ext_uart_ready; //收到数据的同时，清除标志，因为数据已取到ext_uart_buffer中
always @(posedge clk_in) begin          //接收到缓冲区ext_uart_buffer
    if (reset_of_clk) begin
        ext_uart_buffer <= 8'b0;
        ext_uart_avai <= 1'b0;
    end
    else if(ext_uart_ready) begin
        ext_uart_buffer <= ext_uart_rx;
        ext_uart_avai <= 1'b1;
    end 
    else if(cpu_data_addr == 32'hbfd0_03f8 && (cpu_data_e & ~cpu_data_w) && ext_uart_avai)begin 
        ext_uart_avai <= 1'b0;
    end
end

always @(posedge clk_in) begin          //将缓冲区ext_uart_buffer发送出去
    if(!ext_uart_busy && cpu_data_avai) begin 
        ext_uart_tx <= uart_wdata[7:0];
        ext_uart_start <= 1;
    end else begin 
        ext_uart_start <= 0;
    end
end

async_transmitter #(.ClkFrequency(f_clk),.Baud(f_uart)) //发送模块,9600无检验位
    ext_uart_t(
        .clk(clk_in),                   //外部时钟信号
        .TxD(txd),                      //串行信号输出
        .TxD_busy(ext_uart_busy),       //发送器忙状态指示
        .TxD_start(ext_uart_start),     //开始发送信号
        .TxD_data(ext_uart_tx)          //待发送的数据
    );

// | 地址 | 位 | 说明 |
// | --- | --- |--- |
// | 0xBFD003F8| [7:0] | 串口数据，读、写地址分别表示串口接收、发送一个字节|
// | 0xBFD003FC| [0] | 只读，为1时表示串口空闲，可发送数据|
// | 0xBFD003FC| [1] | 只读，为1时表示串口收到数据|

endmodule
