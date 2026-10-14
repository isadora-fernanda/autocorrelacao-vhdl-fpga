-- Testbench do sistema completo: gera o clock de 50 MHz e o reset da placa DE10-Lite.
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity tb_System is
end tb_System;

architecture sim of tb_System is
  signal clk : std_logic := '0';
  signal key : std_logic_vector(1 downto 0) := "00";
begin
  clk <= not clk after 10 ns;   -- 50 MHz
  key <= "11" after 100 ns;     -- solta o reset (KEY0)
  dut : entity work.System port map (MAX10_CLK1_50 => clk, KEY => key);
end sim;
