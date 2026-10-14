-- Módulo right shifter para ponto flutuante

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity right_shifter is
    generic (P: natural:= 27; E: natural := 8; PLOG: natural := 4); -- Padrão 32 bits
    Port (frac : in  std_logic_vector (P downto 0);
           diff_exp : in  std_logic_vector (E downto 0);
           frac_align : out  std_logic_vector (P downto 0));
end right_shifter;

architecture Behavioral of right_shifter is
   signal fracAlign_int : std_logic_vector(P downto 0);
   constant allShifted : std_logic_vector(P downto 0) := (0 =>'1', others =>'0');
   constant ZEROS : std_logic_vector(P downto PLOG) := (others =>'0');

begin
   process(diff_exp, frac)
      variable temp : std_logic_vector(P downto 0);
      variable dtemp : std_logic_vector(P downto 0);
      variable fracAgnVar : std_logic_vector(P downto 0);
      variable sticky : std_logic;
      constant zeros : std_logic_vector(P downto 0) := (others => '0');
   begin
      temp := frac; -- Primeiro salva a mantissa inteira em temp
      sticky := '0'; -- Para arredondamento enquanto o right shifter é aplicado

	  -- Aqui é checado os bits de diff_exp, que é o número de bits na qual a mantissa precisa ser deslocada
	  -- Ou seja, se '1' for encontrado na i-ésima posição, a mantissa será deslocada em 2^i
      for i in PLOG downto 0 loop
         if (diff_exp(i) = '1') then
            dtemp := (others => '0');
            dtemp(P - 2**i downto 0) := temp(P downto 2**i); -- Salva a parte da mantissa do bit mais significativo até o 2^i-ésimo bit (a parte que não é descartada)
            if temp(2**i -1 downto 0) /= zeros(2**i downto 0) then -- Se a parte descartada não for 0, o sticky recebe '1'
               sticky := '1';
            end if;
         else -- Se (diff_exp(i) = '0')
            dtemp := temp;
         end if;
       temp := dtemp; -- Salva a mantissa para a próxima verificação
      end loop;

	  -- No final, após todas as verificações, a mantissa resultante é mantida e o sticky é usado para o bit menos significativo (arredondamento)
      fracAlign_int <= dtemp(P downto 1) & (dtemp(0) or sticky);

   end process;

	  -- Output do resultado, porém, se o deslocamento foi maior que o número de bits,
	  -- então o resultado foi todo deslocado.
   frac_align <= fracAlign_int when diff_exp(E downto PLOG+1) = ZEROS else allShifted; -- Se diffexp >> P -> allshifted

end Behavioral;