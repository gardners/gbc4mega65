library ieee;
use ieee.std_logic_1164.all;

package video_modes_pkg is

   type video_modes_t is record
      CLK_SEL   : std_logic;  -- 0 : 0: 27 MHz, 1 : 40 MHz
      CLK_KHZ   : integer;    -- Pixel clock frequency in kHz
      H_PIXELS  : integer;    -- horizontal display width in pixels
      V_PIXELS  : integer;    -- vertical display width in rows
      H_PULSE   : integer;    -- horizontal sync pulse width in pixels
      H_BP      : integer;    -- horizontal back porch width in pixels
      H_FP      : integer;    -- horizontal front porch width in pixels
      V_PULSE   : integer;    -- vertical sync pulse width in rows
      V_BP      : integer;    -- vertical back porch width in rows
      V_FP      : integer;    -- vertical front porch width in rows
   end record video_modes_t;

   constant C_VGA_800_600_60 : video_modes_t := (
      CLK_SEL   => '1',       -- 40 MHz
      CLK_KHZ   => 40000,     -- 40 MHz
      H_PIXELS  => 800,       -- horizontal display width in pixels
      V_PIXELS  => 600,       -- vertical display width in rows
      H_PULSE   => 128,       -- horizontal sync pulse width in pixels
      H_BP      => 88,        -- horizontal back porch width in pixels
      H_FP      => 40,        -- horizontal front porch width in pixels
      V_PULSE   => 4,         -- vertical sync pulse width in rows
      V_BP      => 23,        -- vertical back porch width in rows
      V_FP      => 1          -- vertical front porch width in rows
   );

   -- Taken from section 4.9 in the document CEA-861-D
   constant C_VGA_720_576_50 : video_modes_t := (
      CLK_SEL   => '0',       -- 27 MHz
      CLK_KHZ   => 27000,     -- 27 MHz
      H_PIXELS  => 720,       -- horizontal display width in pixels
      V_PIXELS  => 576,       -- vertical display width in rows
      H_PULSE   => 64,        -- horizontal sync pulse width in pixels
      H_BP      => 68,        -- horizontal back porch width in pixels
      H_FP      => 12,        -- horizontal front porch width in pixels
      V_PULSE   => 5,         -- vertical sync pulse width in rows
      V_BP      => 39,        -- vertical back porch width in rows
      V_FP      => 5          -- vertical front porch width in rows
   );

end package video_modes_pkg;

package body video_modes_pkg is
end package body video_modes_pkg;

