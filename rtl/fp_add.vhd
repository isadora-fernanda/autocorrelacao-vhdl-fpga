-- Módulo de adição e subtração para dois pontos flutuantes
-- K representa os bits do ponto flutuante no total
-- E representa os bits do expoente
-- P representa os bits da mantissa (incluindo o '1' fantasma)
-- K = E + P
-- PLOG é o Log na base 2 de (P+3)
-- No padrão de 32 bits: K = 32, E = 8, P = 24, PLOG = 4

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity FP_Add is
    generic(K: natural := 32; P: natural := 24; E: natural := 8);
    Port (FP_A : in  std_logic_vector (K-1 downto 0);
           FP_B : in  std_logic_vector (K-1 downto 0);
           add_sub: in std_logic;
           FP_Z : out  std_logic_vector (K-1 downto 0));
end FP_Add;

architecture Behavioral of FP_Add is
   function log2 (n : natural) return natural is
      variable a, m : natural;
   begin
      a := 0; m := 1;
      while m < n loop
         a := a + 1; m := m * 2;
      end loop;
      return a;
   end log2;
   constant PLOG : natural := log2(P+3) - 1;
   constant ZEROS : std_logic_vector(K-1 downto 0) := (others => '0');
   constant ONES : std_logic_vector(K-1 downto 0) := (others => '1');

   signal expA_FF, expB_FF, expA_Z, expB_Z : std_logic;
   signal fracA_Z, fracB_Z : std_logic;

   signal isNaN_A, isNaN_B, isInf_A, isInf_B, isZero_A, isZero_B, isNaN, isInf : std_logic;
   signal underflow_sub : std_logic;

   signal sign_A, sign_B : std_logic;
   signal exp_A, exp_B  : std_logic_vector(E-1 downto 0);

   signal efectExp: std_logic_vector(E downto 0);

   signal efectFracA, efectFracB, efectFracB_align : std_logic_vector(P+3 downto 0);
   signal diffExpAB, diffExpBA, diffExp : std_logic_vector(E downto 0);
   signal addAB, addSubAB, subAB : std_logic_vector(P+3 downto 0);
   signal frac_add_Norm1    : std_logic_vector(P+3 downto 0);
   signal isSUB : std_logic;

   signal subBAExpEq : std_logic_vector(P+3 downto 0);
   signal frac_sub_Norm1 : std_logic_vector(P+3 downto 0);
   signal sign : std_logic;

   -- Declaração de componentes
   component right_shifter is
   generic (P: natural; E: natural; PLOG: natural);
   Port (frac : in  std_logic_vector (P downto 0);
        diff_exp : in  std_logic_vector (E downto 0);
        frac_align : out  std_logic_vector (P downto 0));
   end component;

   component fp_leading_zeros_and_shift is
   generic (P: natural:= 27; E: natural := 8; PLOG: natural := 4);
   Port ( frac : in  std_logic_vector (P downto 0);
        exp	: in  std_logic_vector (E-1 downto 0);
        frac_Norm : out  std_logic_vector (P downto 0);
        exp_Norm : out  std_logic_vector (E-1 downto 0);
        underFlow : out std_logic);
   end component;

   signal isZero_AorB : std_logic;

   -- Buffers para o segundo estágio
   signal frac, frac_Norm1 : std_logic_vector (P+3 downto 0);
   signal frac_Norm2 : std_logic_vector (P-2 downto 0);
   signal frac_stg2 : std_logic_vector (P+3 downto 0);
   signal exp_Norm1, efectExp_stg2: std_logic_vector(E-1 downto 0);
   signal sign_stg2, isSUB_stg2, isNaN_stg2, isInf_stg2, overflow, underflow: std_logic;
   signal isZero_AorB_stg2: std_logic;
   signal isTwo : std_logic;
   signal exp_add_Norm1, exp_sub_Norm1 : std_logic_vector(E-1 downto 0);
   signal isRoundUp, didNorm1 : std_logic;

begin

   -- Aqui é verificado se A e B são NaN, infinito ou zero,
   -- de acordo com Padrão IEEE 754:
   -- Number 	Sign	Exponent			Mantissa 
   -- 	0		 X		00000000	0000000000000000000000
   --  inf		 0		11111111	0000000000000000000000
   --  -inf		 1		11111111	0000000000000000000000
   --  NaN		 X		11111111			Non-zero

   -- Aqui são verificados se os expoentes de A e B são FF ou 00 - '1' se true, '0' se false
   expA_FF <= '1' when FP_A(K-2 downto K-E-1)= ONES(K-2 downto K-E-1) else '0';
   expB_FF <= '1' when FP_B(K-2 downto K-E-1)= ONES(K-2 downto K-E-1) else '0';
   expA_Z <= '1' when FP_A(K-2 downto K-E-1)= ZEROS(K-2 downto K-E-1) else '0';
   expB_Z <= '1' when FP_B(K-2 downto K-E-1)= ZEROS(K-2 downto K-E-1) else '0';

   -- Aqui é verificado se a mantissa de A e B é zero
   fracA_Z <= '1' when FP_A(P-2 downto 0) = ZEROS(P-2 downto 0) else '0';
   fracB_Z <= '1' when FP_B(P-2 downto 0) = ZEROS(P-2 downto 0) else '0';

   -- Aqui é verificado se A e B são NaN, infinito ou zero - nessa ordem
   -- Se for NaN, o expoente é inteiro '1' e a mantissa é Non-zero
   isNaN_A <= expA_FF and (not fracA_Z);
   isNaN_B <= expB_FF and (not fracB_Z);

   -- Se for infinito, o expoente é inteiro '1' e a mantissa não é verificada (NaN tem prioridade)
   isInf_A <= expA_FF;
   isInf_B <= expB_FF;

   -- Aqui é verificado se A e B são zero (mantissa & expoente - ambos devem ser inteiros '0')
   isZero_A <= expA_Z and fracA_Z;
   isZero_B <= expB_Z and fracB_Z;
   isZero_AorB <= isZero_A or isZero_B;

   -- NaN e infinito
   -- Se um deles for NaN, o resultado é NaN e, se ambos forem infinito & subtraídos, o resultado é NaN
   isNaN <= (isNaN_A or isNaN_B) or (isInf_A and isInf_B and isSUB); -- NaN
   -- Se um deles for infinito, o resultado é infinito e, se ambos forem infinitos & somados, o resultado é infinito
   isInf <= (isInf_A xor isInf_B) or (isInf_A and isInf_B and (not isSUB)); -- Infinito

   -- Aqui o sinal e o expoente são salvos
   sign_A <= FP_A(K-1);
   exp_A <= FP_A(K-2 downto K-E-1);

   sign_B <= FP_B(K-1) when add_sub='1' else not FP_B(K-1);
   exp_B <= FP_B(K-2 downto K-E-1);

   -- Se os sinais forem diferentes, então é uma subtração
   isSUB <= sign_A XOR sign_B;

   -- Aqui é verificada a diferença entre os expoentes
   -- É importante destacar que, se os expoentes forem diferentes, o menor tem de ser deslocado
   diffExpAB <= ('0' & exp_A) - ('0' & exp_B); -- Bit extra para o sinal
   diffExpBA <= ('0' & exp_B) - ('0' & exp_A);

   -- diffExp -> abs(exp(B) - exp(A))
   diffExp <= diffExpAB when diffExpAB(E)='0' else diffExpBA; -- No padrão 32 E = 8

   -- Troca
   -- 01 é adicionado ao começo - '1' porque a mantissa não inclui o primeiro '1' (1.mantissa*2^(exp-127)),
   -- '0' para caso a adição necessite de mais um bit e '000' é adicionado ao final para arredondamento,
   -- então efectFracA é 01&mantissa do número de maior exponente&000;
   -- efectFracB é 01&mantissa do número de menor exponente&000;
   -- e efectExp é o número do maior expoente com '0' adicionado ao seu começo

   efectFracA <= "01" & FP_A(P-2 downto 0) & "000" when diffExpAB(E)='0' else "01" & FP_B(P-2 downto 0) & "000";
   efectFracB <= "01" & FP_B(P-2 downto 0) & "000" when diffExpAB(E)='0' else "01" & FP_A(P-2 downto 0) & "000";
   efectExp <= '0' & exp_A when diffExpAB(E)='0' else '0' & exp_B;
   -- efectFracB -> necessita right shift
   -- Fim da troca

   -- Right shifter
   -- A mantissa do menor número é deslocada para a direita diffExp vezes
   alignment: right_shifter
      generic map (P => P+3, E => E, PLOG => PLOG)
      port map(frac => efectFracB, diff_exp => diffExp, frac_align => efectFracB_align);

   -- Adição/Subtração
   -- A e B (agora efectFracA e efectFracB_align) são ambos somados e subtraídos,
   -- já que este módulo comporta tanto soma quanto subtração
   addAB <= efectFracA + efectFracB_align;
   subAB <= efectFracA - efectFracB_align;
   addSubAB <= addAB when isSUB = '0' else subAB ; -- Salva como adição ou subtração, depende do caso

   -- Subtração sem deslocamento (exponentes iguais) - não houve troca
   subBAExpEq <= (("01" & FP_B(P-2 downto 0)) - ("01" & FP_A(P-2 downto 0))) & "000";

   -- Aqui é considerado o caso de A ser 0 - o resultado é B (com o '01' e '000' de arredondamento),
   -- e de B ser 0 - o resultado é A
   -- Se os expoentes forem iguais, o resultado é subBAExpEq - caso tenha seja subtração e
   -- addSubAB - caso seja soma
   frac <= "01" & FP_B(P-2 downto 0) & "000" when isZero_A='1' else
           "01" & FP_A(P-2 downto 0) & "000" when isZero_B='1' else
         subBAExpEq when subBAExpEq(P+3) = '0' and exp_A = exp_B and isSUB = '1' else
         addSubAB;

   -- Sinal
   -- Se os sinais forem iguais, o sinal resultante é o mesmo de A e, senão, o sinal resultante é o do maior expoente
   sign <= sign_A when sign_A = sign_B else
         sign_B when diffExpAB(E)='1' else
         sign_A when addSubAB(P+3)='0' else sign_B;

   -- Normalização e arredondamento
   -- As variáveis são copiadas com identificador '_stg2'
   frac_stg2 <= frac;
   efectExp_stg2 <= efectExp(E-1 downto 0);
   isZero_AorB_stg2 <= isZero_AorB;
   isNaN_stg2 <= isNaN;
   isInf_stg2 <= isInf;
   sign_stg2 <= sign;
   isSUB_stg2 <= isSUB;

   -- Primeira normalização

   -- Para adição
   -- Aqui o '0' de '01' adicionado será utilizado - se, agora, for um '1', a mantissa terá de ser deslocada,
   -- na qual o bit menos significativo é calculado através do 'OR' dos dois últimos bits para arredondamento do resultado
   addition_norm: process(frac_stg2)
   begin
      if (frac_stg2(P+3)='1') then
         frac_add_Norm1 <= '0' & frac_stg2(P+3 downto 2)&(frac_stg2(1) or frac_stg2(0));
         didNorm1 <= '1';
      else
         frac_add_Norm1 <= frac_stg2;
         didNorm1 <= '0';
      end if;
   end process;

   -- Se ambos os últimos bits forem '1', então é arredondado para cima
   isTwo <= '1' when (frac_stg2(P+2 downto 2)= ONES(P+2 downto 2)) else '0'; -- Só pode acontecer na adição
   -- Então o expoente normalizado é calculado, o qual é o do resultado da adição - necessitando adicionar
   -- didNorm1 ou isTwo, caso tenha sido normalizado ou arredondado
   exp_add_Norm1 <= efectExp_stg2 + (didNorm1 or isTwo);

   -- Subtração
   -- Aqui a normalização é feita para a subtração, que deve ocorrer caso hajam '0's no começo do resultado,
   -- que terá de ser deslocado para a esquerda
   -- Também pode haver underflow, caso o resultado seja pequeno demais para o padrão de 32 bits utilizado
   subtraction_norm: fp_leading_zeros_and_shift
   generic map(P => P+3, E => E, PLOG => PLOG)
   port map(
      frac       => frac_stg2,
      exp        => efectExp_stg2,
      frac_Norm  => frac_sub_Norm1,
      exp_Norm   => exp_sub_Norm1,
      underFlow  => underflow_sub
   );

   -- Aqui mantissa e expoente são salvos, resultados de adição ou subtração
   frac_Norm1 <= frac_add_Norm1 when isSUB_stg2 = '0' else frac_sub_Norm1;
   exp_Norm1 <= exp_add_Norm1(E-1 downto 0)  when isSUB_stg2 = '0' else exp_sub_Norm1(E-1 downto 0);

   -- Arredondamento
   -- Os três últimos bits de arredondamento são descartados, e o bit menos significativo é resultado do arredondamento deles
   isRoundUp <= '1' when ( (frac_Norm1(2) = '1' and (frac_Norm1(1) = '1' or frac_Norm1(0) = '1')) or frac_Norm1(3 downto 0)="1100") else '0';
   frac_Norm2 <= frac_Norm1(P+1 downto 3) + isRoundUp;

   -- Overflow e underflow
   overflow <= '1' when (exp_Norm1 = ONES(E-1 downto 0) and (isSUB_stg2 = '0')) else '0';
   underflow <= underflow_sub when isSUB_stg2 = '1' else '0';

   -- Aqui os casos especiais (vistos no começo) são considerados
   FP_Z <= sign_stg2 & ONES(E-1 downto 0) & ZEROS(P-2 downto 1) & '1' when isNaN_stg2='1' else
               sign_stg2 & ONES(E-1 downto 0) & ZEROS(P-2 downto 0) when (isInf_stg2='1' or overflow = '1') else
               sign_stg2 & efectExp_stg2(E-1 downto 0) & frac_stg2(P+1 downto 3) when isZero_AorB_stg2 = '1' else
               sign_stg2 & ZEROS(K-2 downto 0) when underflow='1' else
               sign_stg2 & exp_Norm1 & frac_Norm2;

end Behavioral;