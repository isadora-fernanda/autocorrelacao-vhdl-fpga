-- Módulo de multiplicação complexa

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Aqui é multiplicado (R1+I1i)(R2+I2i)
-- no qual o resultado é salvo em R e I - R é a parte real e I a parte imaginária
entity complex_multiplier is
    Port (R1 : in  STD_LOGIC_VECTOR (31 downto 0);
           I1 : in  STD_LOGIC_VECTOR (31 downto 0);
           R2 : in  STD_LOGIC_VECTOR (31 downto 0);
           I2 : in  STD_LOGIC_VECTOR (31 downto 0);
           R : out  STD_LOGIC_VECTOR (31 downto 0);
           I : out  STD_LOGIC_VECTOR (31 downto 0));
end complex_multiplier;


-- Utiliza módulos para a multiplicação dos pontos
architecture Behavioral of complex_multiplier is
	COMPONENT FP_mul
	PORT(
		FP_A : IN std_logic_vector(31 downto 0);
		FP_B : IN std_logic_vector(31 downto 0);
		FP_Z : OUT std_logic_vector(31 downto 0)
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
	signal R1R2, I1I2, R1I2, I1R2  : std_logic_vector(31 downto 0):=(others=>'0');
begin
	-- (R1+I1i)(R2+I2i) = R1*R2 + R1*I2i + I1*R1i - I1*I2

	-- Parte Real --

	-- Aqui R1*R2 é computado
	Inst_FP_mul_1: FP_mul PORT MAP(
		FP_A => R1,
		FP_B => R2,
		FP_Z =>	R1R2 
	);
	-- Aqui I1*I2 é computado
	Inst_FP_mul_2: FP_mul PORT MAP(
		FP_A => I1,
		FP_B => I2,
		FP_Z =>	I1I2
	);

	-- Parte real da solução R1*R2 - I1*I2, a flag add_sub = '0' indica que é subtração
	Inst_FP_Add_1: FP_Add PORT MAP(
		FP_A => R1R2,
		FP_B => I1I2,
		add_sub => '0',
		FP_Z => R
	);

	-- Parte imaginária --

	-- Aqui R1*I2 é computado
	Inst_FP_mul_3: FP_mul PORT MAP(
		FP_A => R1,
		FP_B => I2,
		FP_Z =>	R1I2
	);
	-- Aqui I1*R2 é computado
	Inst_FP_mul_4: FP_mul PORT MAP(
		FP_A => I1,
		FP_B => R2,
		FP_Z =>	I1R2
	);

	-- Parte imaginária da solução R1*I2 + I1*R2, a flag add_sub = '1' indica que é adição
	Inst_FP_Add_2: FP_Add PORT MAP(
		FP_A => R1I2,
		FP_B => I1R2,
		add_sub => '1',
		FP_Z => I
	);
end Behavioral;