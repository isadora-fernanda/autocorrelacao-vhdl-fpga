-- Módulo Memory_Block
-- Leia o arquivo do TCC2 antes! Ficará mais fácil de entender
-- Caso seja armazenamento, we é igual a ‘1’ e data_in será utilizado,
-- uma vez que contém o número que será armazenado. Ainda nesse caso,
-- o bit menos significativo de addr_a indica o que será armazenado.
-- Por outro lado, caso seja leitura, we é igual ‘0’,
-- data_in não é utilizado e o bit menos significativo de
-- addr_a indica de que Random Access Memory (RAM) o número armazenado
-- será lido em d_out_a. Além disso, d_out_b possibilita a
-- leitura do endereço contido em addr_b.
-- Lembrando que addr_b_1 e addr_b_2 são sempre trocados, iniciando-se com '0' e '1'
-- para ser possível realizar a autocorrelação com lag 1 (multiplica '0' com '1', '1' com '2', etc).


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity Memory_Block is
    Port ( clk : in  STD_LOGIC;
           addr_a : in  STD_LOGIC_VECTOR(7 downto 0); -- Read/Write
			  addr_b_1 : in  STD_LOGIC_VECTOR(6 downto 0); -- Lê o primeiro número complexo
			  addr_b_2 : in  STD_LOGIC_VECTOR(6 downto 0); -- Lê o segundo número complexo
	        we : in  STD_LOGIC;
           data_in    : in  STD_LOGIC_VECTOR(31 downto 0);
			  -- 1 word output mode
			  dout_a     : out  STD_LOGIC_VECTOR(31 downto 0);  -- Mostra 1 output
			  -- 4 word output mode
           dout_b_1   : out  STD_LOGIC_VECTOR(31 downto 0);  -- R1
			  dout_b_2   : out  STD_LOGIC_VECTOR(31 downto 0);  -- I1
           dout_b_3   : out  STD_LOGIC_VECTOR(31 downto 0);  -- R2
			  dout_b_4   : out  STD_LOGIC_VECTOR(31 downto 0)   -- I2
			  );
end Memory_Block;

architecture Behavioral of Memory_Block is
	COMPONENT RAM
	PORT(
		clk : IN std_logic;
		addr_a : IN std_logic_vector(6 downto 0);
		addr_b : IN std_logic_vector(6 downto 0);
		data_a : IN std_logic_vector(31 downto 0);
		we_a : IN std_logic;
		q_a : OUT std_logic_vector(31 downto 0);
		q_b : OUT std_logic_vector(31 downto 0)
		);
	END COMPONENT;
	signal we1, we2, we3, we4 : std_logic := '0';
	signal q_a_1 :std_logic_vector(31 downto 0);
	signal q_a_2 :std_logic_vector(31 downto 0);
	signal q_a_3 :std_logic_vector(31 downto 0);
	signal q_a_4 :std_logic_vector(31 downto 0);
	signal addr_reg :std_logic_vector(1 downto 0);
begin
we1 <= not(addr_a(0)) and we; -- '0', ou seja, leitura
we2 <=    (addr_a(0)) and we; -- '1', ou seja, data_in será utilizado (escrita)

process (clk)
begin
   if (clk'event and clk = '1') then
     addr_reg <= addr_a(1 downto 0);
   end if;
end process;
-- O output é selecionado dependendo dos dois últimos bits do address register
dout_a <=   q_a_1 when addr_reg(1 downto 0)="00" else
				q_a_2 when addr_reg(1 downto 0)="01" else
				q_a_3 when addr_reg(1 downto 0)="10" else
				q_a_4; -- "11"


	-- Para todas as 4 Int_RAM, o input é data_in, ou seja, o valor que está sendo guardado	
	-- addr_a é usado para sinalizar em qual RAM o valor será guardado (R1, R2, I1, I2)	
	Inst_RAM_1: RAM PORT MAP(
		clk => clk,
		addr_a => addr_a(7 downto 1),
		addr_b => addr_b_1(6 downto 0),
		data_a => data_in,
		we_a => we1,
		q_a => q_a_1,
		q_b => dout_b_1 -- R1
	);
	Inst_RAM_2: RAM PORT MAP(
		clk => clk,
		addr_a => addr_a(7 downto 1),
		addr_b => addr_b_1(6 downto 0),
		data_a => data_in,
		we_a => we2,
		q_a => q_a_2,
		q_b => dout_b_2 -- I1
	);
	Inst_RAM_3: RAM PORT MAP(
		clk => clk,
		addr_a => addr_a(7 downto 1),
		addr_b => addr_b_2(6 downto 0),
		data_a => data_in,
		we_a => we1,
		q_a => q_a_3,
		q_b => dout_b_3 -- R2
	);
	Inst_RAM_4: RAM PORT MAP(
		clk => clk,
		addr_a => addr_a(7 downto 1),
		addr_b => addr_b_2(6 downto 0),
		data_a => data_in,
		we_a => we2,
		q_a => q_a_4,
		q_b => dout_b_4 -- I2
	);
end Behavioral;