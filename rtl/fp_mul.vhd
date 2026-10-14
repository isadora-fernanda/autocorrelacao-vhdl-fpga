-- Módulo de multiplicação para dois pontos flutuantes
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

entity FP_mul is
   generic(K: natural:= 32; P: natural:= 24; E: natural:= 8);
   port (FP_A : in  std_logic_vector (K-1 downto 0);
        FP_B : in  std_logic_vector (K-1 downto 0);
        FP_Z : out  std_logic_vector (K-1 downto 0));
end FP_mul ;

architecture one_cycle of FP_mul is

   -- Constantes
   constant ZEROS : std_logic_vector(K-1 downto 0) := (others => '0');
   constant ONES : std_logic_vector(K-1 downto 0) := (others => '1');

   -- Buffers
   signal frac_A, frac_B : std_logic_vector(P-1 downto 0):= (others => '0');
   signal sign_A, sign_B : std_logic:='0';
   signal exp_A, exp_B  : std_logic_vector(E-1 downto 0):= (others => '0');
   signal expA_FF, expB_FF, expA_Z, expB_Z : std_logic:='0';
   signal fracA_Z, fracB_Z : std_logic:='0';

   signal isNaN_A, isNaN_B, isInf_A, isInf_B, isZero_A, isZero_B, isNaN, isInf : std_logic:='0';

   signal prod: std_logic_vector(2*P-1 downto 0):= (others => '0');
   signal sticky, isZero: std_logic:='0';

   signal exp_stg2, exp_res, exp_int: std_logic_vector(E-1 downto 0):= (others => '0');
   signal exp_pos, exp_neg : std_logic:='0';
   signal exp_pos_stg2, exp_neg_stg2  : std_logic:='0';
   signal sign_stg2, sign_res : std_logic:='0';
   signal frac_stg2, frac_res : std_logic_vector((P+3) downto 0):= (others => '0');
   signal isInf_stg2, isNaN_stg2, isZ_stg2  : std_logic:='0';

   signal frac_norm: std_logic_vector (P+2 downto 0):= (others => '0');
   signal frac_round: std_logic_vector(P-1 downto 0):= (others => '0');
   signal frac_final: std_logic_vector(P-2 downto 0):= (others => '0');
   signal isRoundUp, didNorm, isTwo: std_logic:='0';

   signal exp_final: std_logic_vector(E-1 downto 0):= (others => '0');
   signal frac_isZ, isZero_f, isInf_f: std_logic:='0';
   signal overflow, underflow: std_logic:='0';

begin

   -- Salva as diferentes partes de A e B (sinal, expoente, mantissa)
   -- e adiciona '1' na mantissa porque a mantissa não inclui o primeiro '1' (1.mantissa*2^(exp-127))
   sign_A <= FP_A(K-1);
   sign_B <= FP_B(K-1);
   exp_A  <= FP_A(K-2 downto K-E-1);
   exp_B  <= FP_B(K-2 downto K-E-1);
   frac_A <= '1' & FP_A(P-2 downto 0);
   frac_B <= '1' & FP_B(P-2 downto 0);

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
   expA_Z  <= '1' when FP_A(K-2 downto K-E-1)= ZEROS(K-2 downto K-E-1) else '0';
   expB_Z  <= '1' when FP_B(K-2 downto K-E-1)= ZEROS(K-2 downto K-E-1) else '0';

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

   -- Computação
   -- Se um deles for NaN, o resultado é NaN,
   -- se um deles for 0 e o outro for infinito, o resultado também é NaN
   isNaN <= (isInf_A and isZero_B) or (isZero_A and isInf_B) or (isNaN_A or isNaN_B);
   -- Se um deles é infinito, o resultado é infinito
   isInf <= isInf_A or isInf_B;
   -- Se um deles for zero, o resultado é 0
   isZero <= isZero_A or isZero_B;
   -- Se as regras acima se contradizerem, a ordem de prioridade é NaN > Inf > 0

   -- Operação
   -- As mantissas são multiplicadas e armazenadas em um vetor duas vezes o tamanho do original, para nenhum bit ser descartado
   prod(2*P-1 downto 0) <= (unsigned(frac_A(P-1 downto 0)) * unsigned(frac_B(P-1 downto 0)));

   -- Aqui o 'sticky' bit é calculado:
   -- O sticky_gen - um process - procura pelo primeiro '1' em A e B (direita p. esquerda) e salva a posição,
   -- para verificar se o bit menos significativo da multiplicação será 0 ou 1. Então o resto é descartado para caber em 32 bits, com o
   -- 'sticky' sendo concatenado no final

   sticky_gen:process(frac_A, frac_B)
      variable firstOne_A, firstOne_B : natural;
      constant NZ : natural := P-4; -- para o padrão binary32 utilizado aqui é 20
   begin
      firstOne_A := NZ+1; firstOne_B := NZ+1;
      for i in 0 to NZ loop
         if frac_A(i) = '1' then
            firstOne_A := i; exit;
         end if;
      end loop;
      for i in 0 to NZ loop
         if frac_B(i) = '1' then
            firstOne_B := i; exit;
         end if;
      end loop;
      if firstOne_A + firstOne_B <= NZ then sticky <= '1';
      else sticky <= '0';
      end if;
   end process;

   frac_res <= prod(2*P-1 downto P-3) & sticky;

   -- O expoente final é a soma dos expoentes de A e B, lembrando que é exp - 127
   -- então o bit mais significativo tem que ser negado para remover o bias
   exp_int <= exp_A + exp_B + '1'; -- e1 + e2 - bias = e1 + e2 - 2^n+1
   exp_res <= (not exp_int(E-1)) & exp_int(E-2 downto 0);
   sign_res <= sign_A xor sign_B;

   -- O sinal do expoente é calculado e salvo nas variáveis abaixo, que mostram se o expoente é positivo ou negativo
   exp_pos  <= exp_A(E-1) and exp_B(E-1);
   exp_neg  <= not (exp_A(E-1) or exp_B(E-1));

   -- Segunda parte
   -- As variáveis são copiadas com identificador '_stg2'
   frac_stg2     <= frac_res;
   exp_pos_stg2  <= exp_pos;
   exp_neg_stg2  <= exp_neg;
   sign_stg2     <= sign_res;
   isInf_stg2    <= isInf;
   isNaN_stg2    <= isNaN;
   isZ_stg2      <= isZero;
   exp_stg2      <= exp_res;

   -- Aqui é verificado se a mantissa precisa ser normalizada, e, para isso, o bit mais significativo é utilizado,
   -- se for '1', a mantissa é deslocada um lugar, os dois últimos dígitos são arredondados e a flag didNorm é setada
   Nomalization: process(frac_stg2)
   begin
      if (frac_stg2(P+3)='1') then
         frac_norm <= frac_stg2(P+3 downto 2) & (frac_stg2(1) or frac_stg2(0));
         didNorm <= '1';
      else
         frac_norm <= frac_stg2(P+2 downto 0);
         didNorm <= '0';
      end if;
   end process;

   -- Aqui é usado o bit menos significativo para verificar se é necessário arredondar o final da mantissa
   isRoundUp <= '1' when ((frac_norm(2) = '1' and (frac_norm(1) = '1' or frac_norm(0) = '1')) or frac_norm(3 downto 0)="1100") else '0';
   frac_round <= unsigned(frac_norm(P+2 downto 3)) + isRoundUp;

   -- Se for tudo '1', a mantissa é arredondada para cima
   isTwo <= '1' when (frac_stg2(P+2 downto 2)= ONES(P+2 downto 2)) else '0';
   -- Calcula o expoente final, que é o original + 1 caso tenha sido normalizado ou arredondado
   exp_final <= unsigned(exp_stg2) + (didNorm or isTwo);

   frac_final <= frac_round(P-2 downto 0); -- descarta o '1' fantasma
   -- Verifica se a mantissa é 0
   frac_isZ <= '1' when ((frac_norm(P+2 downto 2)=ZEROS(P downto 0))) else '0';
   isZero_f <= frac_isZ or isZ_stg2;

   -- Overflow
   overflow <= '1' when ( ((exp_stg2(E-1 downto 1) = ONES(E-1 downto 1)) and (exp_stg2(0) = '1' or didNorm ='1' or isTwo='1')  and (exp_neg_stg2='0'))  
                         or ((exp_pos_stg2='1') and (exp_stg2(E-1)='0')) ) else '0';

   -- Underflow
   underflow <= '1' when (exp_neg_stg2='1' and exp_stg2(E-1)='1') or (exp_stg2(E-1 downto 0) = ZEROS(E-1 downto 0) and didNorm='0' and isTwo='0') else '0';

   -- Verifica se resultado é infinito (overflow é infinito, ao menos que seja NaN, então é checado se a mantissa não é 0)
   isInf_f <= (isInf_stg2 or overflow) and (not isZero_f);

   -- Resultado
   packing: process(sign_stg2, isNaN_stg2,isInf_f, isZero_f, exp_final, frac_final, underflow)
   begin
     FP_Z(K-1) <= sign_stg2;

     if (isNaN_stg2='1') then -- Se for NaN
         FP_Z(K-2 downto P-1) <= ONES(E-1 downto 0);
         FP_Z(P-2 downto 0) <= '1'& ZEROS(P-3 downto 0);
      elsif (isInf_f='1') then -- Se for infinito ou overflow
         FP_Z(K-2 downto P-1) <= ONES(E-1 downto 0);
         FP_Z(P-2 downto 0) <= ZEROS(P-2 downto 0);
      elsif (isZero_f='1') or (underflow = '1') then -- Se for 0 ou underflow
         FP_Z(K-2 downto P-1) <= ZEROS(E-1 downto 0);
         FP_Z(P-2 downto 0) <= ZEROS(P-2 downto 0);
       else -- Se não haver nenhum caso especial, o resultado calculado é computado
         FP_Z(K-2 downto P-1) <= exp_final;
         FP_Z(P-2 downto 0) <= frac_final;
      end if;
   end process;
end one_cycle;