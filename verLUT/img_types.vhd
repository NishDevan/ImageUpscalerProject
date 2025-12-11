-- Type Definitions (VHDL-93)
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package img_types is
    type pixel_rgb is record
        r : integer range 0 to 255;
        g : integer range 0 to 255;
        b : integer range 0 to 255;
    end record;
    type img_buffer is array (natural range<>, natural range<>) of pixel_rgb;
end package img_types;
