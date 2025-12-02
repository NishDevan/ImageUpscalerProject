library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

package Upscaler_Pkg is
    type Window_Array is array (0 to 5) of integer;
    type Coeff_Array is array (0 to 5) of integer;

    constant IMG_WIDTH  : integer := 16;
    constant IMG_HEIGHT : integer := 16;
end package Upscaler_Pkg;