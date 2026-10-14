-- Módulo RAM

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity RAM is
   Generic(depth: integer := 128;
	        addr_width : integer := 7);
	port
	(
		clk	: in std_logic;
		addr_a	: in std_logic_vector(addr_width-1 downto 0);
		addr_b	: in std_logic_vector(addr_width-1 downto 0);
		data_a	: in std_logic_vector(31 downto 0);
		we_a	: in std_logic;
		q_a	: out std_logic_vector(31 downto 0);
		q_b	: out std_logic_vector(31 downto 0)
	);
end RAM;

architecture Behavioral of RAM is
	type memory_type is array(0 to depth-1) of std_logic_vector(31 downto 0);
	signal memory : memory_type := (others=>(others=>'0'));
begin
process (clk)
begin
   if (clk'event and clk = '1') then
         if (we_a = '1') then
            memory(to_integer(unsigned(addr_a))) <= data_a; -- Se write enable está ativado o input data to memory é guardado no endereço a
         end if;
         q_a <= memory(to_integer(unsigned(addr_a))) ; -- Se write enable está inativado o que está guardado no endereço a e b
         q_b <= memory(to_integer(unsigned(addr_b))) ; -- é guardado nos outputs q_a e q_b
   end if;
end process;

end Behavioral;