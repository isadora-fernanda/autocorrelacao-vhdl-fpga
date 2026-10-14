-- Modelo de simulação que substitui o sistema Nios II (proc_sys) no GHDL.
-- Faz no barramento a mesma sequência do programa em C (nios/main.c):
-- escreve os 128 pares complexos, envia o comando de início, espera o fim
-- e lê a autocorrelação calculada pela FPGA.
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.float_pkg.all;

entity proc_sys is
  port (
    clk_clk                                                 : in  std_logic;
    reset_reset_n                                           : in  std_logic;
    to_external_bus_bridge_0_external_interface_acknowledge : in  std_logic;
    to_external_bus_bridge_0_external_interface_irq         : in  std_logic;
    to_external_bus_bridge_0_external_interface_address     : out std_logic_vector(11 downto 0);
    to_external_bus_bridge_0_external_interface_bus_enable  : out std_logic;
    to_external_bus_bridge_0_external_interface_byte_enable : out std_logic_vector(3 downto 0);
    to_external_bus_bridge_0_external_interface_rw          : out std_logic;
    to_external_bus_bridge_0_external_interface_write_data  : out std_logic_vector(31 downto 0);
    to_external_bus_bridge_0_external_interface_read_data   : in  std_logic_vector(31 downto 0)
  );
end proc_sys;

architecture sim of proc_sys is
  type word_array is array (0 to 255) of std_logic_vector(31 downto 0);
  -- Amostras reais da posição 12,95 mm (mesmos valores do programa em C), parte real e imaginária intercaladas
  constant DADOS : word_array := (
    x"C2EB0F3E",
    x"C2B8DC52",
    x"431F5643",
    x"418E3EEE",
    x"C063FECD",
    x"432D4FCD",
    x"C2EC7646",
    x"C29CF121",
    x"42E49681",
    x"C31D826C",
    x"42D9D751",
    x"420F913F",
    x"C2FD2B40",
    x"42B14D83",
    x"C25428B0",
    x"C2B48528",
    x"42AC1E89",
    x"41BC3312",
    x"C28DFA03",
    x"42C2F5FA",
    x"C1BBC9BE",
    x"C254AAA5",
    x"42D9A042",
    x"C0C539DE",
    x"C2817A4F",
    x"41ADEF73",
    x"C0FFC785",
    x"C27AC114",
    x"41F4DC54",
    x"41E1BE71",
    x"C2B6BCCF",
    x"4229F016",
    x"4151FAD1",
    x"C2285DC9",
    x"416C25D3",
    x"41DDCC9D",
    x"C2041E93",
    x"C202E923",
    x"42BD70C7",
    x"4173C6E0",
    x"C21285AA",
    x"424F106C",
    x"C302C12B",
    x"C2499F36",
    x"C19D7CDF",
    x"C3029759",
    x"434D3F1D",
    x"C1B46A33",
    x"411A0311",
    x"435CEBE9",
    x"C36A2A1E",
    x"C13D4057",
    x"4307C406",
    x"C3AFC956",
    x"435CC73C",
    x"42E2BACA",
    x"C2F9B9EF",
    x"432015A3",
    x"C341580C",
    x"C36ECBAA",
    x"424DB70E",
    x"C2A46B1C",
    x"C1873F63",
    x"431EAD75",
    x"C3C093F0",
    x"C2AFC92E",
    x"42DAC1E4",
    x"C2ACAF01",
    x"426475EF",
    x"42FE03AA",
    x"C221EC9A",
    x"C17A3D7B",
    x"C200DFCC",
    x"C23FFED1",
    x"C1B33843",
    x"C290DE89",
    x"4291FCBE",
    x"C172BCDF",
    x"416A2B84",
    x"42CB66E6",
    x"C289EF67",
    x"41E38FC9",
    x"421BAE13",
    x"C243FD4A",
    x"C150BC5C",
    x"41AE34FF",
    x"40B33A4C",
    x"C2C2E9A6",
    x"435E2A81",
    x"41FC3E01",
    x"C29EF02B",
    x"428EA364",
    x"C2AC6924",
    x"C2CF1F67",
    x"4300D5AB",
    x"C1A469BD",
    x"40EE8CA3",
    x"43099734",
    x"C318B5AC",
    x"C1C8DE5D",
    x"43BB36B6",
    x"C41822E2",
    x"429030EA",
    x"424A2DD7",
    x"C1F9059A",
    x"4298BCC8",
    x"C3075F2C",
    x"4203C925",
    x"40B02015",
    x"C2823A7A",
    x"42C29E31",
    x"C180E5A6",
    x"C201C0D5",
    x"41B3C0A7",
    x"C01C2C8A",
    x"C08D765F",
    x"41DE68D0",
    x"C2418224",
    x"416F34F0",
    x"42CA88BD",
    x"C26FEB94",
    x"42B358F1",
    x"C211BA96",
    x"C2F5C14E",
    x"432D696A",
    x"BEBE55E4",
    x"C146E9A9",
    x"42FD8D7F",
    x"C2E95BBD",
    x"C313DC19",
    x"42844F3A",
    x"C232A885",
    x"BFB7D530",
    x"4187E3F4",
    x"413B4366",
    x"42ACB8B8",
    x"C3183B81",
    x"C0878038",
    x"42D46EB4",
    x"C34A64DF",
    x"433F7068",
    x"42D697CC",
    x"C2BA4AA0",
    x"42AF7320",
    x"C1F0578D",
    x"C1C9792E",
    x"C217B364",
    x"C1BA27EE",
    x"41FB0481",
    x"C20E3FA2",
    x"4187341C",
    x"424B8F9E",
    x"423F74EF",
    x"C1BE3FF9",
    x"C0F101A7",
    x"42DF5344",
    x"C2FFC87E",
    x"C29DC414",
    x"4279BC36",
    x"C3079EB3",
    x"3F412891",
    x"42D9B567",
    x"C25536C2",
    x"C0A945AF",
    x"4258C416",
    x"415B7592",
    x"C2474C11",
    x"C11BDFDF",
    x"4288A068",
    x"C2D2C0A6",
    x"427C2440",
    x"417A09ED",
    x"C1D4FACA",
    x"C25FC4DB",
    x"4229E649",
    x"C2848011",
    x"418C6827",
    x"42431137",
    x"C2CA2F8F",
    x"40FE6168",
    x"C1B49645",
    x"3FCB8ABA",
    x"41E27580",
    x"41872A36",
    x"C1C1EEA6",
    x"C1E5BC51",
    x"426B7700",
    x"C247AB63",
    x"42983ADE",
    x"42A0EA4F",
    x"C38D121B",
    x"C2251866",
    x"4071E107",
    x"C30520A8",
    x"420E9F83",
    x"42DA1E72",
    x"C2D3C90C",
    x"C1039537",
    x"42EED2F0",
    x"C21AE498",
    x"3F38DDBB",
    x"42AB7385",
    x"C0B03FB8",
    x"C37BE051",
    x"42D3AD48",
    x"C1B0DCF5",
    x"C2D9A254",
    x"42AA3E81",
    x"42235D3D",
    x"C332C7D0",
    x"3E8BB140",
    x"42DE770C",
    x"C2A8BE0E",
    x"C2D3E2A6",
    x"42DEF1EF",
    x"C28CBD7D",
    x"C1EC856D",
    x"42C1B072",
    x"C2527943",
    x"C2BFF8A6",
    x"4120A2B5",
    x"4233AEDD",
    x"C3056A08",
    x"BF472512",
    x"42CF6A02",
    x"C28DA109",
    x"4153F101",
    x"4280D3B0",
    x"C27C7D18",
    x"C31A1B01",
    x"42D82627",
    x"C24B21BE",
    x"44478AD8",
    x"C21A11B0",
    x"C25AF023",
    x"C2AB0FF7",
    x"41023B22",
    x"C12ABB53",
    x"C21A5AB1",
    x"42DBA034",
    x"412421CF",
    x"C113C769",
    x"425D2139",
    x"42235051",
    x"C3892DC3",
    x"41C4C0AB",
    x"4237E15C",
    x"C2A5F74D",
    x"429D0D11",
    x"419C218D",
    x"C2EBD8FA",
    x"40B693C0",
    x"C2557B86",
    x"C22480FE",
    x"3F3E8D2E",
    x"422D370E"
  );
  alias addr : std_logic_vector(11 downto 0) is to_external_bus_bridge_0_external_interface_address;
  alias en   : std_logic is to_external_bus_bridge_0_external_interface_bus_enable;
  alias rw   : std_logic is to_external_bus_bridge_0_external_interface_rw;
  alias wdat : std_logic_vector(31 downto 0) is to_external_bus_bridge_0_external_interface_write_data;
  alias rdat : std_logic_vector(31 downto 0) is to_external_bus_bridge_0_external_interface_read_data;
begin
  to_external_bus_bridge_0_external_interface_byte_enable <= "1111";

  process
    procedure escreve(endereco : natural; dado : std_logic_vector(31 downto 0)) is
    begin
      wait until falling_edge(clk_clk);
      addr <= std_logic_vector(to_unsigned(endereco, 12)); wdat <= dado; rw <= '0'; en <= '1';
      wait until falling_edge(clk_clk);
      en <= '0'; rw <= '1';
    end procedure;
    procedure le(endereco : natural; dado : out std_logic_vector(31 downto 0)) is
    begin
      wait until falling_edge(clk_clk);
      addr <= std_logic_vector(to_unsigned(endereco, 12)); rw <= '1'; en <= '1';
      wait until falling_edge(clk_clk);
      dado := rdat; en <= '0';
    end procedure;
    variable st, re_v, im_v : std_logic_vector(31 downto 0);
    variable ciclos : natural := 0;
  begin
    en <= '0'; rw <= '1'; addr <= (others => '0'); wdat <= (others => '0');
    wait until reset_reset_n = '1';
    for i in 0 to 255 loop
      escreve(i * 4, DADOS(i));               -- IOWR_32DIRECT(base, j, ...)
    end loop;
    escreve(512 * 4, x"00000001");           -- CTRL_REG = 1 (início)
    loop                                     -- espera STATUS_REG(0) = 1
      le(513 * 4, st);
      ciclos := ciclos + 1;
      exit when st(0) = '1';
    end loop;
    le(256 * 4, re_v);                       -- parte real do resultado
    le(257 * 4, im_v);                       -- parte imaginária do resultado
    report "Autocorrelacao (FPGA): " & to_string(to_real(to_float(re_v))) &
           " + j(" & to_string(to_real(to_float(im_v))) & ")";
    report "Hex: real = 0x" & to_hstring(re_v) & "  imag = 0x" & to_hstring(im_v);
    escreve(512 * 4, x"00000000");           -- ack(): CTRL_REG = 0
    report "Fim da simulacao" severity note;
    std.env.stop;
    wait;
  end process;
end sim;
