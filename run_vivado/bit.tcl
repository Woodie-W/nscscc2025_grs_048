# bit.tcl
open_project ./project/thinpad_top.xpr

# reset_run impl_1
# reset_run synth_1

launch_runs impl_1 -to_step write_bitstream
wait_on_run impl_1  

open_run impl_1
report_timing_summary -delay_type min_max -report_unconstrained \
    -file project/thinpad_top.runs/impl_1/timing_summary.rpt
exit
