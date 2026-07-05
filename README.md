# 16-bit Pipelined ALU — RTL to GDS
 
This project is a full RTL-to-GDS implementation of a 16-bit pipelined ALU that I built on the SAED 32nm PDK using the Synopsys flow. I took the design all the way from Verilog RTL to a routed GDSII layout, going through verification, synthesis, and place-and-route.
 
I built this to get hands-on with the complete physical design flow rather than just reading about it, so I could actually see how RTL becomes real gates and then a physical chip.
 
## The design
 
It's a 2-stage pipelined ALU, 16 bits wide. Two pipeline stages means it has a 2-cycle latency but can take a new operation every clock.
 
Supported operations: add, subtract, AND, OR, XOR, NOT, logical/arithmetic shifts, rotates, signed and unsigned set-less-than, equality, and pass-through. It also outputs zero, carry, overflow, and negative flags.
 
Technology: SAED 32nm, RVT cells, typical corner (0.85 V, 25 °C).
 
## What I did (the flow)
 
1. **Verification (VCS + Verdi)** — wrote a self-checking testbench with a reference model and a scoreboard, ran it in VCS, and used Verdi to check the waveforms. Confirmed the 2-cycle pipeline latency and correct flag behavior. All tests passed.
2. **Synthesis (Design Compiler)** — synthesized the RTL to a gate-level netlist on SAED 32nm. Around 1,186 gates, meeting timing at 500 MHz. I also swept the clock to find the max frequency (~667 MHz) and looked at how tightening the clock traded off against area.
3. **Place & Route (IC Compiler II)** — did floorplanning, placement, power planning, clock tree synthesis, and routing. Closed timing with about +0.74 ns slack on extracted parasitics, zero router DRC violations, and wrote out the final GDS.
## Results
 
| Metric | Value |
|---|---|
| Gates (post-synthesis) | ~1,186 |
| Flip-flops | 57 |
| Target clock | 500 MHz (2.0 ns) |
| Max frequency (measured by sweep) | ~667 MHz |
| Post-route worst slack | +0.74 ns setup, 0 hold violations |
| Routed nets | 1,354 |
| Router DRC | 0 violations |
 
One thing I found interesting: after placement I had a tiny hold violation, and CTS fixed it once the real clock tree balanced the arrival times to all 57 flip-flops. Seeing that happen made the point of CTS click for me.
 
I also over-constrained the design to 1 GHz on purpose — the tool added ~17% more area trying to hit it and still failed timing, which showed the speed-vs-area trade-off clearly.
 
## Files
 
```
rtl/            Verilog design
tb/             SystemVerilog testbench
constraints/    SDC timing constraints
scripts/        synthesis + P&R scripts
results/        QoR reports and layout screenshot
```
 
## Tools
 
- Simulation & debug: Synopsys VCS, Verdi
- Synthesis: Synopsys Design Compiler
- Place & route: Synopsys IC Compiler II
## Notes on scope
 
The DRC here is the router's built-in check (clean). Full signoff DRC/LVS (IC Validator) and parasitic signoff (StarRC) weren't part of the kit I used, but I understand where they fit in the flow. Power planning is a basic standard-cell-rail setup, and timing was closed at the typical corner.
 
## What I learned
 
- How RTL becomes gates and then physical layout, step by step
- Why wire delay is the central problem in physical design
- What floorplanning, placement, CTS, and routing each actually do
- Reading timing reports — setup, hold, slack, and timing closure
- How synthesis constraints affect frequency, area, and power
