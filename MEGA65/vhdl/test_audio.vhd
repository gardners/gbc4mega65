----------------------------------------------------------------------------------
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity test_audio is
port (
   clk_i       : in std_logic;
   rst_i       : in std_logic;
   clk_khz_i   : in integer;

   pcm_left_o  : out std_logic_vector(15 downto 0);
   pcm_right_o : out std_logic_vector(15 downto 0);

   pcm_clken_o : out std_logic;
   pcm_acr_o   : out std_logic;                     -- HDMI ACR packet strobe (frequency = 128fs/N e.g. 1kHz)
   pcm_n_o     : out std_logic_vector(19 downto 0); -- HDMI ACR N value
   pcm_cts_o   : out std_logic_vector(19 downto 0)  -- HDMI ACR CTS value
);
end test_audio;

architecture synthesis of test_audio is

signal pcm_clken_count : integer;

begin

   -- Generate sawtooth
   p_audio : process (clk_i)
   begin
      if rising_edge(clk_i) then
         pcm_left_o  <= std_logic_vector(unsigned(pcm_left_o) + 1);
         pcm_right_o <= std_logic_vector(unsigned(pcm_right_o) + 1);
      end if;
   end process p_audio;

   -- Generate signal at 48 kHz.
   p_pcm_clken : process (clk_i)
   begin
      if rising_edge(clk_i) then
         pcm_clken_o <= '0';
         if pcm_clken_count + 48 >= clk_khz_i then
            pcm_clken_count <= pcm_clken_count + 48 - clk_khz_i;
            pcm_clken_o <= '1';
         else
            pcm_clken_count <= pcm_clken_count + 48;
         end if;
      end if;
   end process p_pcm_clken;

   -- N and CTS values for HDMI Audio Clock Regeneration.
   -- depends on pixel clock and audio sample rate
   pcm_n_o   <= std_logic_vector(to_unsigned(6144,  pcm_n_o'length));    -- 48000*128/1000
   pcm_cts_o <= std_logic_vector(to_unsigned(40000, pcm_cts_o'length));  -- vga_clk/1000

   -- ACR packet rate should be 128fs/N = 1kHz
   p_pcm_acr : process (clk_i)
      variable count : integer range 0 to 47;
   begin
      if rising_edge(clk_i) then
         if pcm_clken_o = '1' then  -- 48 kHz
            pcm_acr_o <= '0';
            if count = 47 then
               count := 0;
               pcm_acr_o <= '1';    -- 1 kHz
            else
               count := count+1;                
            end if;
         end if;

         if rst_i = '1' then
            count := 0;
            pcm_acr_o <= '0';
         end if;
      end if;
   end process p_pcm_acr;

end architecture synthesis;

