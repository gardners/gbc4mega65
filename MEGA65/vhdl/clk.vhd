----------------------------------------------------------------------------------
-- Game Boy Color for MEGA65 (gbc4mega65)
--
-- Main clock & QNICE-clock generator using the Xilinx specific MMCME2_ADV
--
-- The MiSTer main expects 8x the clock speed of the original Game Boy:
--   8 x 4.194304 MHz = 33.554432 MHz
-- The QNICE main expects 50 MHz
--
-- This machine is based on Gameboy_MiSTer
-- MEGA65 port done by sy2002 in 2021 and licensed under GPL v3
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library unisim;
use unisim.vcomponents.all;

library xpm;
use xpm.vcomponents.all;

entity clk is
   port (
      sys_clk_i     : in  std_logic;      -- expects 100 MHz
      sys_rstn_i    : in  std_logic;      -- Asynchronous, asserted low
      vga_clkx5_o   : out std_logic;
      vga_clk_o     : out std_logic;      -- Either 27 MHz or 40 MHz
      vga_rst_o     : out std_logic
   );
end clk;

architecture rtl of clk is

   signal clkfb_mmcm     : std_logic;
   signal clkfb          : std_logic;

   signal vga_clkx5_mmcm : std_logic;
   signal vga_clk_mmcm   : std_logic;

begin

   -- VCO frequency range for Artix 7 speed grade -1 : 600 MHz - 1200 MHz
   -- f_VCO = f_CLKIN * CLKFBOUT_MULT_F / DIVCLK_DIVIDE
   i_mmcme2_adv_200_40 : MMCME2_ADV
      generic map (
         BANDWIDTH            => "OPTIMIZED",
         CLKOUT4_CASCADE      => FALSE,
         COMPENSATION         => "ZHOLD",
         STARTUP_WAIT         => FALSE,
         CLKIN1_PERIOD        => 10.0,       -- INPUT @ 100 MHz
         REF_JITTER1          => 0.010,
         DIVCLK_DIVIDE        => 5,
         CLKFBOUT_MULT_F      => 37.125,     -- f_VCO = 742.5 MHz
         CLKFBOUT_PHASE       => 0.000,
         CLKFBOUT_USE_FINE_PS => FALSE,
         CLKOUT0_DIVIDE_F     => 2.000,      -- 371.25 MHz
         CLKOUT0_PHASE        => 0.000,
         CLKOUT0_DUTY_CYCLE   => 0.500,
         CLKOUT0_USE_FINE_PS  => FALSE,
         CLKOUT1_DIVIDE       => 10,         -- 74.25 MHz
         CLKOUT1_PHASE        => 0.000,
         CLKOUT1_DUTY_CYCLE   => 0.500,
         CLKOUT1_USE_FINE_PS  => FALSE
      )
      port map (
         -- Output clocks
         CLKFBOUT            => clkfb_mmcm,
         CLKOUT0             => vga_clkx5_mmcm,
         CLKOUT1             => vga_clk_mmcm,
         -- Input clock control
         CLKFBIN             => clkfb,
         CLKIN1              => sys_clk_i,
         CLKIN2              => '0',
         -- Tied to always select the primary input clock
         CLKINSEL            => '1',
         -- Ports for dynamic reconfiguration
         DADDR               => (others => '0'),
         DCLK                => '0',
         DEN                 => '0',
         DI                  => (others => '0'),
         DO                  => open,
         DRDY                => open,
         DWE                 => '0',
         -- Ports for dynamic phase shift
         PSCLK               => '0',
         PSEN                => '0',
         PSINCDEC            => '0',
         PSDONE              => open,
         -- Other control and status signals
         LOCKED              => open,
         CLKINSTOPPED        => open,
         CLKFBSTOPPED        => open,
         PWRDWN              => '0',
         RST                 => '0'
      ); -- i_mmcme2_adv_200_40 : MMCME2_ADV


   -------------------------------------
   -- Output buffering
   -------------------------------------

   clkfb_bufg : BUFG
      port map (
         I => clkfb_mmcm,
         O => clkfb
      );
      
   vga_clkx5_bufg : BUFG
      port map (
         I => vga_clkx5_mmcm,
         O => vga_clkx5_o
      );

   vga_clk_bufg : BUFG
      port map (
         I => vga_clk_mmcm,
         O => vga_clk_o
      );


   -------------------------------------
   -- Reset generation
   -------------------------------------

   i_xpm_cdc_sync_rst : xpm_cdc_sync_rst
      generic map (
         INIT_SYNC_FF => 1  -- Enable simulation init values
      )
      port map (
         src_rst  => not sys_rstn_i,   -- 1-bit input: Source reset signal.
         dest_clk => vga_clk_o,        -- 1-bit input: Destination clock.
         dest_rst => vga_rst_o         -- 1-bit output: src_rst synchronized to the destination clock domain.
                                       -- This output is registered.
      );
      
end architecture rtl;

