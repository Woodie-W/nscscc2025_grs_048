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


