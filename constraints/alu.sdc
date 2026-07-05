set CLK_PERIOD 2.0
create_clock -name clk -period $CLK_PERIOD [get_ports clk]
set_clock_uncertainty 0.10 [get_clocks clk]
set_input_delay [expr {0.2 * $CLK_PERIOD}] -clock clk [remove_from_collection [all_inputs] [get_ports clk]]
set_output_delay [expr {0.2 * $CLK_PERIOD}] -clock clk [all_outputs]
set_load 0.010 [all_outputs]
