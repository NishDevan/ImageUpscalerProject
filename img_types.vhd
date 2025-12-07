-- Type Definitions
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package img_types is
    subtype pixel_value is integer range 0 to 255;
    type pixel_rgb is record
        r : pixel_value;
        g : pixel_value;
        b : pixel_value;
    end record;
    type img_buffer is array (natural range<>, natural range<>) of pixel_rgb;
end package img_types;
