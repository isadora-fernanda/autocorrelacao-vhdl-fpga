library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.NUMERIC_STD.ALL;

entity System is
    Port ( MAX10_CLK1_50 : in STD_LOGIC;
           KEY : in STD_LOGIC_VECTOR (1 downto 0));
end System;

architecture Behavioral of System is
COMPONENT complex_multiplier
PORT(
	R1 : IN  std_logic_vector(31 downto 0);
	I1 : IN  std_logic_vector(31 downto 0);
	R2 : IN  std_logic_vector(31 downto 0);
	I2 : IN  std_logic_vector(31 downto 0);
	R : OUT  std_logic_vector(31 downto 0);
	I : OUT  std_logic_vector(31 downto 0)
  );
END COMPONENT;
component proc_sys is
  port (
		clk_clk                                                 : in  std_logic                     := 'X';             -- clk
		reset_reset_n                                           : in  std_logic                     := 'X';             -- reset_n
		to_external_bus_bridge_0_external_interface_acknowledge : in  std_logic                     := 'X';             -- acknowledge
		to_external_bus_bridge_0_external_interface_irq         : in  std_logic                     := 'X';             -- irq
		to_external_bus_bridge_0_external_interface_address     : out std_logic_vector(11 downto 0);                    -- address
		to_external_bus_bridge_0_external_interface_bus_enable  : out std_logic;                                        -- bus_enable
		to_external_bus_bridge_0_external_interface_byte_enable : out std_logic_vector(3 downto 0);                     -- byte_enable
		to_external_bus_bridge_0_external_interface_rw          : out std_logic;                                        -- rw
		to_external_bus_bridge_0_external_interface_write_data  : out std_logic_vector(31 downto 0);                    -- write_data
		to_external_bus_bridge_0_external_interface_read_data   : in  std_logic_vector(31 downto 0) := (others => 'X')  -- read_data
  );
end component proc_sys;
    COMPONENT Memory_Block
    PORT(
        clk : IN  std_logic;
		  addr_a : in  STD_LOGIC_VECTOR(7 downto 0); -- Read/Write RAM address
		  addr_b_1 : in  STD_LOGIC_VECTOR(6 downto 0); -- 1o complexo
		  addr_b_2 : in  STD_LOGIC_VECTOR(6 downto 0); -- 2o complexo
		  we : in  STD_LOGIC;
		  data_in    : in  STD_LOGIC_VECTOR(31 downto 0);
		  -- 1 word output mode
		  dout_a     : out  STD_LOGIC_VECTOR(31 downto 0);  -- shows 1 output
		  -- 4 word output mode
		  dout_b_1   : out  STD_LOGIC_VECTOR(31 downto 0);  -- R1
		  dout_b_2   : out  STD_LOGIC_VECTOR(31 downto 0);  -- I1
		  dout_b_3   : out  STD_LOGIC_VECTOR(31 downto 0);  -- R2
		  dout_b_4   : out  STD_LOGIC_VECTOR(31 downto 0)   -- I2
        );
    END COMPONENT;
	COMPONENT FP_Add
	PORT(
		FP_A : IN std_logic_vector(31 downto 0);
		FP_B : IN std_logic_vector(31 downto 0);
		add_sub : IN std_logic;
		FP_Z : OUT std_logic_vector(31 downto 0)
		);
	END COMPONENT;
type state_type is (s0, s1, s2, s3, s4, s5);

signal state : state_type := s0;

-- Inputs
signal R1 : std_logic_vector(31 downto 0);
signal I1 : std_logic_vector(31 downto 0);
signal R2 : std_logic_vector(31 downto 0);
signal I2, conj_I2 : std_logic_vector(31 downto 0);

-- Outputs
signal R : std_logic_vector(31 downto 0);
signal I : std_logic_vector(31 downto 0);

signal R_REG : std_logic_vector(31 downto 0);
signal I_REG : std_logic_vector(31 downto 0);

signal R_SUM : std_logic_vector(31 downto 0);
signal I_SUM : std_logic_vector(31 downto 0);

signal acknowledge :  std_logic ;
signal address     :  std_logic_vector(11 downto 0); -- address
signal enable, bus_enable  :  std_logic;             -- bus_enable
signal byte_enable :  std_logic_vector(3 downto 0);  -- byte_enable
signal rw          :  std_logic;                     -- rw
signal write_data  :  std_logic_vector(31 downto 0); -- write_data
signal input_memory_data, output_memory_data   :   std_logic_vector(31 downto 0);

signal addr_a : std_logic_vector(6 downto 0) := (others => '0');
signal addr_b_1, addr_b_2 : std_logic_vector(6 downto 0) := (others => '0');
signal input_memory_we          :  std_logic;
signal output_memory_we         :  std_logic;
signal effective_address : std_logic_vector(9 downto 0);
signal CTRL_REG    :  std_logic_vector(31 downto 0);
signal STATUS_REG  :  std_logic_vector(31 downto 0);
signal read_data   :  std_logic_vector(31 downto 0);
alias start : std_logic is CTRL_REG(0);
alias done  : std_logic is STATUS_REG(0);
begin
   effective_address <= address(11 downto 2); -- O adress mode do processador é +4, porém a FPGA usa +1, então os últimos
															 -- dois bits são ignorados para dividir por 4
   conj_I2 <= not(I2(31)) & I2(30 downto 0);
	complex_multiplier_Inst: complex_multiplier PORT MAP ( -- Aqui o multiplier faz (R(k+1) + Ii(k+1))*(R(k) - Ii(k))
          R1 => R1,										  			 -- para o k-ésimo passo da autocorrelação
          I1 => I1,
          R2 => R2,
          I2 => conj_I2,
          R => R,
          I => I
        );
  Inst_FP_Add_1: FP_Add PORT MAP(
		FP_A => R,
		FP_B => R_REG,
		add_sub => '1',
		FP_Z => R_SUM
	);
	Inst_FP_Add_2: FP_Add PORT MAP(
		FP_A => I,
		FP_B => I_REG,
		add_sub => '1',
		FP_Z => I_SUM
	);
    u0 : component proc_sys
        port map (
            clk_clk                                                 => MAX10_CLK1_50, -- clk.clk
            reset_reset_n                                           => KEY(0),        -- reset.reset_n
            to_external_bus_bridge_0_external_interface_acknowledge => acknowledge,   -- to_external_bus_bridge_0_external_interface.acknowledge
            to_external_bus_bridge_0_external_interface_irq         => '0',           -- .irq
            to_external_bus_bridge_0_external_interface_address     => address,       -- .address
            to_external_bus_bridge_0_external_interface_bus_enable  => bus_enable,    -- .bus_enable
            to_external_bus_bridge_0_external_interface_byte_enable => byte_enable ,  -- .byte_enable
            to_external_bus_bridge_0_external_interface_rw          => rw,            -- .rw
            to_external_bus_bridge_0_external_interface_write_data  => write_data,    -- .write_data
            to_external_bus_bridge_0_external_interface_read_data   => read_data      -- .read_data
        );

-- skip the acknowledge process
	process(MAX10_CLK1_50)
	begin
	if rising_edge(MAX10_CLK1_50) then
		acknowledge <= bus_enable;
	end if;
	end process;

process(MAX10_CLK1_50)
begin
if rising_edge(MAX10_CLK1_50) then
	if(rw='0' and bus_enable='1')then -- rw = '0' para escrever, bus_enable = '1' para bits válidos
		if(effective_address=512)then -- effective_address = 512 para início de comando
			CTRL_REG <= write_data; -- Lembrando que CTRL_REG que continua ou finaliza o programa (vide Nios II)
		end if;
	end if;
end if;
end process;

read_data <= CTRL_REG            when effective_address=512    else -- 512 address = start command
             STATUS_REG          when effective_address=513    else -- 513 address = hold status (0 se rodando, 1 se terminou)
				 R_REG               when effective_address=256    else -- 256 e 257 adress é onde o resultado da autocorrelação é salvo
				 I_REG               when effective_address=257    else
             input_memory_data;


-- rw = '0' para escrever, bus_enable = '1' para bits válidos e effective_address(9) é 
-- o bit mais significativo de address; então, se effective_adress(9) = 255 (2^8-1) ou menos,
-- o qual é o espaço da memória onde os 256 números serão salvos, a escrita pode ocorrer
input_memory_we <= not(rw) and bus_enable and not(effective_address(9));
input_memory: Memory_Block PORT MAP (
		 clk => MAX10_CLK1_50,
		 addr_a => effective_address(7 downto 0),
		 addr_b_1 => addr_b_1,
		 addr_b_2 => addr_b_2,
		 we => input_memory_we,
		 data_in => write_data,
		 dout_a => input_memory_data,
		 dout_b_1 => R1,
		 dout_b_2 => I1,
		 dout_b_3 => R2,
		 dout_b_4 => I2
	  );

process(MAX10_CLK1_50)
begin
if rising_edge(MAX10_CLK1_50) then
	output_memory_we <= '0';
	done <= '0';
	case state is
		when s0 =>  -- Estado inicial, os registradores são zerados e os endereços são setados como '0' e '1' para
						-- multiplicar o número 0 com 1, 1 com 2, etc.
		   R_REG <= (others=>'0');
			I_REG <= (others=>'0');
		   addr_b_1 <= (others=>'0');
			addr_b_2 <= "0000001";
			if(start='1')then  -- Quando o início é setado (vide Nios II), as somas são iniciadas
				state <= s1;
			end if;
		when s1 => -- Espera pelos dados da RAM
					  -- É necessário esperar dois ciclos para ler da memória e realizar os cálculos
			state <= s2;
		when s2 => -- Espera pelos cálculos
			state <= s3;
		when s3 => -- Guarda o resultado na RAM
				     -- Uma vez que esse passo está feito, a soma parcial é guardada para o início do próximo passo
			output_memory_we <= '1';
			R_REG <= R_SUM;
			I_REG <= I_SUM;
			state <= s4;
		when s4 =>
			if (addr_b_2>= 127) then -- 128 passos acabaram? Fim!
				state <= s5;
			else
				addr_b_2 <= addr_b_2 + 1; -- Senão, os endereços recebem + 1 para realizar a próxima multiplicação/soma etc. 
				addr_b_1 <= addr_b_1 + 1; -- e volta para o estado 's1'
				state <= s1;
			end if;
		when s5 =>
		   done <= '1'; -- Todas as operações foram feitas e o resultado é válido (disponível na memória para ser lido pelo Nios II)
			if(start='0')then
				state <= s0;
			else
				state <= s5;
			end if;
		when others => state <= s0;
	end case;
end if;
end process;

end Behavioral;
