----------------------------------------------------------------------------------
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.types_pkg.all;

library xpm;
use xpm.vcomponents.all;

entity top_test_hdmi is
port (
   CLK            : in std_logic;                  -- 100 MHz clock
   RESET_N        : in std_logic;                  -- CPU reset button

   -- VGA
   VGA_RED        : out std_logic_vector(7 downto 0);
   VGA_GREEN      : out std_logic_vector(7 downto 0);
   VGA_BLUE       : out std_logic_vector(7 downto 0);
   VGA_HS         : out std_logic;
   VGA_VS         : out std_logic;

   -- VDAC
   vdac_clk       : out std_logic;
   vdac_sync_n    : out std_logic;
   vdac_blank_n   : out std_logic;

   -- 3.5mm analog audio jack
   pwm_l          : out std_logic;
   pwm_r          : out std_logic;
      
   -- Digital Video
   tmds_data_p    : out std_logic_vector(2 downto 0);
   tmds_data_n    : out std_logic_vector(2 downto 0);
   tmds_clk_p     : out std_logic;
   tmds_clk_n     : out std_logic;

   -- MEGA65 smart keyboard controller
   kb_io0         : out std_logic;                 -- clock to keyboard
   kb_io1         : out std_logic;                 -- data output to keyboard
   kb_io2         : in std_logic                   -- data input from keyboard
);
end top_test_hdmi;

architecture synthesis of top_test_hdmi is

-- rendering constants
constant GB_DX              : integer := 160;          -- Game Boy's X pixel resolution
constant GB_DY              : integer := 144;          -- ditto Y
constant VGA_DX             : integer := 800;          -- SVGA mode 800 x 600 @ 60 Hz
constant VGA_DY             : integer := 600;          -- ditto
constant GB_TO_VGA_SCALE    : integer := 4;            -- 160 x 144 => 4x => 640 x 576

-- Constants for VGA output
constant FONT_DX            : integer := 16;
constant FONT_DY            : integer := 16;
constant CHARS_DX           : integer := VGA_DX / FONT_DX;
constant CHARS_DY           : integer := VGA_DY / FONT_DY;
constant CHAR_MEM_SIZE      : integer := CHARS_DX * CHARS_DY;

-- clocks
signal main_clk             : std_logic;               -- Game Boy core main clock @ 33.554432 MHz
signal vga_clk              : std_logic;               -- SVGA mode 800 x 600 @ 60 Hz: 40.00 MHz
signal vga_clk5             : std_logic;               -- Digital Video output: 200.00 MHz
signal qnice_clk            : std_logic;               -- QNICE main clock @ 50 MHz

-- resets
signal main_rst             : std_logic;               -- Game Boy core main clock @ 33.554432 MHz
signal vga_rst              : std_logic;               -- SVGA mode 800 x 600 @ 60 Hz: 40.00 MHz
signal qnice_rst            : std_logic;               -- QNICE main clock @ 50 MHz


---------------------------------------------------------------------------------------------
-- main_clk
---------------------------------------------------------------------------------------------

-- Audio
signal main_pcm_audio_left  : std_logic_vector(15 downto 0);
signal main_pcm_audio_right : std_logic_vector(15 downto 0);
signal main_pcm_clken       : std_logic;
signal main_pcm_acr         : std_logic;                     -- HDMI ACR packet strobe (frequency = 128fs/N e.g. 1kHz)
signal main_pcm_n           : std_logic_vector(19 downto 0); -- HDMI ACR N value
signal main_pcm_cts         : std_logic_vector(19 downto 0); -- HDMI ACR CTS value


---------------------------------------------------------------------------------------------
-- vga_clk
---------------------------------------------------------------------------------------------

signal vga_disp_en          : std_logic;
signal vga_col              : integer range 0 to VGA_DX - 1;
signal vga_row              : integer range 0 to VGA_DY - 1;
signal vga_tmds             : slv_9_0_t(0 to 2);              -- parallel TMDS symbol stream x 3 channels


begin

   -- MMCME2_ADV clock generators:
   --    Main clock:          33.554432 MHz
   --    QNICE co-processor:  50 MHz
   --    Pixelclock:          40 MHz
   i_clk : entity work.clk
      port map
      (
         sys_clk_i    => CLK,
         sys_rstn_i   => RESET_N,
         main_clk_o   => main_clk,         -- Core's 33.554432 MHz main clock
         main_rst_o   => main_rst,         -- Core's reset, synchronized
         qnice_clk_o  => qnice_clk,        -- QNICE's 50 MHz main clock
         qnice_rst_o  => qnice_rst,        -- QNICE's reset, synchronized
         pixel_clk_o  => vga_clk,          -- VGA's 40.00 MHz pixelclock for SVGA mode 800 x 600 @ 60 Hz
         pixel_rst_o  => vga_rst,          -- VGA's reset, synchronized
         pixel_clk5_o => vga_clk5          -- VGA's 200.00 MHz pixelclock for Digital Video
      ); -- i_clk : entity work.clk


   ---------------------------------------------------------------------------------------------
   -- main_clk
   ---------------------------------------------------------------------------------------------

   i_mega65kbd_to_matrix : entity work.mega65kbd_to_matrix
      port map
      (
          ioclock        => main_clk,
          flopmotor      => '0',
          flopled        => '0',
          powerled       => '1',    
          kio8           => kb_io0,
          kio9           => kb_io1,
          kio10          => kb_io2,
          matrix_col     => open,
          matrix_col_idx => 0,
          capslock_out   => open     
      ); -- i_mega65kbd_to_matrix : entity work.mega65kbd_to_matrix

   i_test_audio : entity work.test_audio
      port map (
         clk_i       => main_clk,
         rst_i       => main_rst,
         pcm_left_o  => main_pcm_audio_left,
         pcm_right_o => main_pcm_audio_right,
         pcm_clken_o => main_pcm_clken,
         pcm_acr_o   => main_pcm_acr,
         pcm_n_o     => main_pcm_n,
         pcm_cts_o   => main_pcm_cts
      ); -- i_test_audio : entity work.test_audio

   -- Convert the Game Boy's PCM output to pulse density modulation
   -- TODO: Is this component configured correctly when it comes to clock speed, constants used within
   -- the component, subtracting 32768 while converting to signed, etc.
   pcm2pdm : entity work.pcm_to_pdm
      port map
      (
         cpuclock    => main_clk,
         pcm_left    => signed(main_pcm_audio_left) - 32768,
         pcm_right   => signed(main_pcm_audio_right) - 32768,
         pdm_left    => pwm_l,
         pdm_right   => pwm_r,
         audio_mode  => '0'
      ); -- pcm2pdm : entity work.pcm_to_pdm


   ---------------------------------------------------------------------------------------------
   -- vga_clk
   ---------------------------------------------------------------------------------------------

   -- SVGA mode 800 x 600 @ 60 Hz
   -- Component that produces VGA timings and outputs the currently active pixel coordinate (row, column)
   -- Timings taken from http://tinyvga.com/vga-timing/800x600@60Hz
   vga_pixels_and_timing : entity work.vga_controller
      generic map
      (
         H_PIXELS  => VGA_DX,      -- horizontal display width in pixels
         V_PIXELS  => VGA_DY,      -- vertical display width in rows

         H_PULSE   => 128,         -- horizontal sync pulse width in pixels
         H_BP      => 88,          -- horizontal back porch width in pixels
         H_FP      => 40,          -- horizontal front porch width in pixels
         H_POL     => '1',         -- horizontal sync pulse polarity (1 = positive, 0 = negative)

         V_PULSE   => 4,           -- vertical sync pulse width in rows
         V_BP      => 23,          -- vertical back porch width in rows
         V_FP      => 1,           -- vertical front porch width in rows
         V_POL     => '1'          -- vertical sync pulse polarity (1 = positive, 0 = negative)
      )
      port map
      (
         pixel_clk => vga_clk,       -- pixel clock at frequency of VGA mode being used
         reset_n   => not vga_rst,   -- active low
         h_sync    => vga_hs,        -- horizontal sync pulse
         v_sync    => vga_vs,        -- vertical sync pulse
         disp_ena  => vga_disp_en,   -- display enable ('1' = display time, '0' = blanking time)
         column    => vga_col,       -- horizontal pixel coordinate
         row       => vga_row,       -- vertical pixel coordinate
         n_blank   => open,          -- direct blacking output to DAC
         n_sync    => open           -- sync-on-green output to DAC
      ); -- vga_pixels_and_timing : entity work.vga_controller

   -- Generate Video
   vga_red   <= X"00" when vga_disp_en = '0' else
                X"FF" when vga_col = 0 or vga_col = 799 or vga_row = 0 or vga_row = 599 else
                X"77";
   vga_green <= X"00" when vga_disp_en = '0' else
                X"FF" when vga_col = 0 or vga_col = 799 or vga_row = 0 or vga_row = 599 else
                X"55";
   vga_blue  <= X"00" when vga_disp_en = '0' else
                X"FF" when vga_col = 0 or vga_col = 799 or vga_row = 0 or vga_row = 599 else
                X"33";

   -- make the VDAC output the image
   -- for some reason, the VDAC does not like non-zero values outside the visible window
   -- maybe "vdac_sync_n <= '0';" activates sync-on-green?
   -- TODO: check that
   vdac_sync_n  <= '0';
   vdac_blank_n <= '1';
   vdac_clk     <= not vga_clk; -- inverting the clock leads to a sharper signal for some reason


   ---------------------------------------------------------------------------------------------
   -- Dual Clocks
   ---------------------------------------------------------------------------------------------

   i_vga_to_hdmi : entity work.vga_to_hdmi
      port map (
         select_44100 => '0',
         dvi          => '0',
         vic          => std_logic_vector(to_unsigned(17,8)), -- CEA/CTA VIC 17=576p50 PAL, 2 = 480p60 NTSC
         aspect       => "01",                                -- 01=4:3, 10=16:9
         pix_rep      => '0',                                 -- no pixel repetition
         vs_pol       => '1',                                 -- 1=active high
         hs_pol       => '1',

         vga_rst      => vga_rst,                             -- active high reset
         vga_clk      => vga_clk,                             -- VGA pixel clock
         vga_vs       => vga_vs,
         vga_hs       => vga_hs,
         vga_de       => vga_disp_en,
         vga_r        => vga_red,
         vga_g        => vga_green,
         vga_b        => vga_blue,

         -- PCM audio
         pcm_rst      => main_rst,
         pcm_clk      => main_clk,
         pcm_clken    => main_pcm_clken,
         pcm_l        => std_logic_vector(main_pcm_audio_left  xor X"8000"),
         pcm_r        => std_logic_vector(main_pcm_audio_right xor X"8000"),
         pcm_acr      => main_pcm_acr,
         pcm_n        => main_pcm_n,
         pcm_cts      => main_pcm_cts,

         -- TMDS output (parallel)
         tmds         => vga_tmds
      ); -- i_vga_to_hdmi: entity work.vga_to_hdmi


   -- serialiser: in this design we use TMDS SelectIO outputs
   GEN_HDMI_DATA: for i in 0 to 2 generate
   begin
      HDMI_DATA: entity work.serialiser_10to1_selectio
      port map (
         rst     => vga_rst,
         clk     => vga_clk,
         clk_x5  => vga_clk5,
         d       => vga_tmds(i),
         out_p   => TMDS_data_p(i),
         out_n   => TMDS_data_n(i)
      ); -- HDMI_DATA: entity work.serialiser_10to1_selectio
   end generate GEN_HDMI_DATA;

   HDMI_CLK: entity work.serialiser_10to1_selectio
   port map (
         rst     => vga_rst,
         clk     => vga_clk,
         clk_x5  => vga_clk5,
         d       => "0000011111",
         out_p   => TMDS_clk_p,
         out_n   => TMDS_clk_n
      ); -- HDMI_CLK: entity work.serialiser_10to1_selectio
      
end architecture synthesis;

