set LIB_HOME "/data/pdk/pdk32nm/SAED32_EDK/lib/stdcell_rvt/db_nldm"
set STD_DB   "saed32rvt_tt0p85v25c.db"
set target_library [list $LIB_HOME/$STD_DB]
set link_library   [list * $LIB_HOME/$STD_DB]

set TOP "alu_16bit_pipeline"
set RTL "alu_16bit_pipeline.v"
file mkdir reports
file mkdir netlist

read_verilog $RTL
current_design $TOP
link
check_design > reports/check_design.rpt

source alu.sdc
compile_ultra

report_qor                           > reports/qor.rpt
report_timing -max_paths 5 -nworst 5 > reports/timing.rpt
report_area   -hierarchy             > reports/area.rpt
report_power                         > reports/power.rpt

echo "==================== QoR SUMMARY ===================="
report_qor

write -format verilog -hierarchy -output netlist/${TOP}_netlist.v
write -format ddc     -hierarchy -output netlist/${TOP}.ddc
write_sdc                                netlist/${TOP}.sdc
echo "==================== DONE ===================="
exit
