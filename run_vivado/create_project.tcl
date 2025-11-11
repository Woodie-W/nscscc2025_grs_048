# SET PROJECT NAME
set  project_name thinpad_top
set  project_path ./project
set  project_part xc7a200tfbg676-2

# CLEAR
file delete -force $project_path

create_project -force $project_name $project_path -part $project_part

# Add conventional sources
add_files -scan_for_includes [glob -nocomplain ../src/mycpu]
# add_files -scan_for_includes [glob -nocomplain ../src/mycpu/*.v]
# add_files -scan_for_includes [glob -nocomplain ../src/mycpu/*/*.v]

# Add IPs
add_files -quiet [glob -nocomplain ../src/mycpu/xilinx_ip/*/*.xci]
add_files -quiet [glob -nocomplain ../src/mycpu/xilinx_ip/*/*.xcix]

# Add simulation files
#add_files -fileset sim_1 ./simulation

# Add constraints
add_files -fileset constrs_1 -quiet ./constraints

# # 递归函数收集指定后缀文件
# proc collect_files_recursive {dir pattern} {
#     set result {}
#     if {[file isdirectory $dir]} {
#         foreach f [glob -nocomplain -directory $dir *] {
#             if {[file isdirectory $f]} {
#                 set result [concat $result [collect_files_recursive $f $pattern]]
#             } elseif {[string match $pattern [file tail $f]]} {
#                 lappend result $f
#             }
#         }
#     }
#     return $result
# }

# # Add myCPU/xilinx_ip: 递归添加 .xci 文件
# set xci_files [collect_files_recursive "../../../IP/myCPU/xilinx_ip" "*.xci"]
# foreach f $xci_files {
#     puts "Add XCI file: $f"
#     add_files $f
# }

# 升级所有IP
upgrade_ip -quiet [get_ips]

set_property top thinpad_top [current_fileset]
# set_property -name "top" -value "tb_top" -objects  [get_filesets sim_1]
# set_property -name {xsim.simulate.log_all_signals} -value {true} -objects [get_filesets sim_1]
# set_property strategy Flow_PerfOptimized_high [get_runs synth_1]
# set_property strategy Performance_Explore [get_runs impl_1]
# set_property -name "top" -value "tb_top" -objects  [get_filesets sim_1]
# set_property -name "xsim.simulate.log_all_signals" -value "1" -objects [get_filesets sim_1]
