#!/bin/sh
# Simula o sistema completo no GHDL, com um modelo no lugar do Nios II.
set -e
mkdir -p work
for f in ../rtl/right_shifter.vhd ../rtl/fp_leading_zeros_and_shift.vhd ../rtl/fp_add.vhd ../rtl/fp_mul.vhd \
         ../rtl/complex_multiplier.vhd ../rtl/RAM.vhd ../rtl/Memory_Block.vhd proc_sys_sim.vhd ../rtl/System.vhd tb_System.vhd; do
  ghdl -a --std=08 -fsynopsys --workdir=work "$f"
done
ghdl -e --std=08 -fsynopsys --workdir=work tb_System
ghdl -r --std=08 -fsynopsys --workdir=work tb_System --ieee-asserts=disable
