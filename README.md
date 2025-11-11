# 仓库描述

## 仓库模板结构
.   
├── asm&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;<font color='red'>汇编测试程序目录。</font>  
│　　├── Makefile&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;<font color='red'>编译汇编程序的 Makefile。</font>  
│　　└── user-sample.s&emsp;&emsp;&emsp;&emsp;&emsp;&ensp;<font color='red'>示例汇编程序。</font>  
│  
├── run_vivado&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&ensp;<font color='red'>Vivado 工程运行相关文件。</font>  
│　　├── constraints&emsp;&emsp;&emsp;&emsp;&emsp;&ensp;<font color='red'>引脚约束文件。</font>  
│　　├── simulation&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;<font color='red'>仿真资源目录。</font>  
│　　├── create_project.tcl&emsp;&emsp;<font color='red'>Vivado 工程创建脚本。</font>  
│　　└── bit.tcl&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&ensp;<font color='red'>生成比特流脚本。</font>  
│  
├── src&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;<font color='red'>源码目录。</font>  
│　　├── mycpu&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;<font color='red'>CPU 源码及 Xilinx IP。</font>  
│　　│　　├── *.v&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&ensp;<font color='red'>工程模板文件，包含 CPU 顶层及相关模块。</font>  
│　　│　　└── xilinx_ip&emsp;&emsp;&emsp;&emsp;&emsp;<font color='red'>工程调用的 Xilinx IP，每个 IP 独立文件夹。</font>  
│　　│  
│　　└── vivado_cannot&emsp;&emsp;&emsp;&emsp;&ensp;<font color='red'>非 Vivado 可直接综合语言源码及编译说明。</font>  
│  
├── .gitlab-ci.yml&emsp;&emsp;&emsp;&emsp;&emsp;&ensp;<font color='red'>CI/CD 配置文件（禁止修改）。</font>  
└── design.pdf&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&ensp;<font color='red'>CPU 设计报告。</font>  

---

## 注意事项
1. **作品提交声明**  
　　- 在FPGA实验平台只允许绑定此仓库以标记commit作为有效成绩，未按此规定的标记的commit记为无效提交，其决赛性能成绩取初赛性能成绩。  
　　- 作为有效标记的commit需包含设计文档。  
2. **main**分支是受保护的模板分支，请基于main分支建立自己的分支，进行设计文件的添加；如果main分支有变动，请使用rebase进行同步。  
2. **禁止修改** `.gitlab-ci.yml` 与 `tcl` 脚本。请严格按照脚本要求放置文件，否则可能导致无法生成工程与产物。  
3. **Xilinx IP 使用规范**  
　　- 若调用了 Xilinx IP（例如 Block RAM IP），需将定制文件 `*.xci`（或 `*.xcix`）放置于 `src/mycpu/xilinx_ip/` 目录下。  
　　- 每个 IP 独立文件夹存放，且文件夹中**仅包含** `.xci` 或 `.xcix` 文件，不得包含综合生成的文件。  
4. **非 Vivado 支持语言**  
　　- 若使用 Vivado 无法直接综合的硬件描述语言（如 Scala、Chisel），需提供：  
　　　　- 完整源码  
　　　　- 编译说明  
5. **参考与借鉴声明**  
　　- 若 CPU 设计中参考了任何资料（如教材），需在文档中明确声明。 
