-- Lanczos Engine (VHDL-93) - FIXED NEGATIVE RANGE
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.img_types.all;

entity lanczos_resample_engine is
    generic(
        SRC_W     : natural := 100;
        SRC_H     : natural := 100;
        SCALE_FAC : natural := 2
    );
    port(
        clk       : in std_logic;
        rst_n     : in std_logic;
        go        : in std_logic;
        src_data  : in img_buffer(0 to SRC_W-1, 0 to SRC_H-1);
        dst_data  : out img_buffer(0 to SRC_W*SCALE_FAC-1, 0 to SRC_H*SCALE_FAC-1);
        finished  : out std_logic
    );
end entity lanczos_resample_engine;

architecture rtl of lanczos_resample_engine is
    constant BORDER_SIZE : natural := 3;
    constant SCALE       : natural := 256;

    type lanczos_lut_type is array(0 to 255) of integer range -128 to 256;
    constant LANCZOS_LUT : lanczos_lut_type := (
        256, 256, 256, 255, 255, 254, 254, 253,
        252, 251, 250, 248, 247, 245, 244, 242,
        240, 238, 236, 233, 231, 229, 226, 223,
        221, 218, 215, 212, 209, 206, 202, 199,
        196, 192, 189, 185, 181, 178, 174, 170,
        166, 162, 158, 154, 150, 146, 142, 138,
        134, 130, 126, 122, 118, 113, 109, 105,
        101, 97, 93, 89, 85, 81, 77, 73,
        69, 65, 62, 58, 54, 50, 47, 43,
        40, 36, 33, 30, 27, 23, 20, 17,
        14, 12, 9, 6, 3, 1, -2, -4,
        -6, -9, -11, -13, -15, -17, -18, -20,
        -22, -23, -25, -26, -27, -29, -30, -31,
        -32, -33, -34, -34, -35, -36, -36, -36,
        -37, -37, -37, -38, -38, -38, -38, -38,
        -37, -37, -37, -37, -36, -36, -36, -35,
        -35, -34, -33, -33, -32, -31, -31, -30,
        -29, -28, -28, -27, -26, -25, -24, -23,
        -22, -21, -20, -20, -19, -18, -17, -16,
        -15, -14, -13, -12, -11, -10, -10, -9,
        -8, -7, -6, -5, -5, -4, -3, -2,
        -2, -1, 0, 0, 1, 1, 2, 2,
        3, 3, 4, 4, 5, 5, 5, 6,
        6, 6, 7, 7, 7, 7, 7, 8,
        8, 8, 8, 8, 8, 8, 8, 8,
        8, 8, 8, 8, 8, 8, 7, 7,
        7, 7, 7, 7, 6, 6, 6, 6,
        6, 5, 5, 5, 5, 5, 4, 4,
        4, 4, 4, 3, 3, 3, 3, 3,
        2, 2, 2, 2, 2, 2, 1, 1,
        1, 1, 1, 1, 1, 1, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0
    );

    function saturate(val : integer) return integer is
    begin
        if val > 255 then return 255;
        elsif val < 0 then return 0;
        else return val;
        end if;
    end function;

    function get_lanczos_weight(frac_scaled : integer; kernel_idx : integer) return integer is
        variable distance_scaled, lut_index : integer;
    begin
        distance_scaled := abs((kernel_idx - 2) * SCALE - frac_scaled);
        lut_index := (distance_scaled * 255) / (3 * SCALE);
        if lut_index > 255 then lut_index := 255; end if;
        return LANCZOS_LUT(lut_index);
    end function;

    component border_replicator is
        generic(IMG_WIDTH : natural; IMG_HEIGHT : natural; BORDER_SZ : natural);
        port(clk : in std_logic; rst_n : in std_logic; trigger : in std_logic;
             src_img : in img_buffer(0 to IMG_WIDTH-1, 0 to IMG_HEIGHT-1);
             bordered_img: out img_buffer(0 to IMG_WIDTH+2*BORDER_SZ-1, 0 to IMG_HEIGHT+2*BORDER_SZ-1);
             complete : out std_logic);
    end component;

    type engine_state is (IDLE, BORDER_PREP, CONVOLVE, OUTPUT_WAIT, COMPLETE);
    signal state : engine_state;
    signal bordered_src : img_buffer(0 to SRC_W+2*BORDER_SIZE-1, 0 to SRC_H+2*BORDER_SIZE-1);
    signal output_buf : img_buffer(0 to SRC_W*SCALE_FAC-1, 0 to SRC_H*SCALE_FAC-1);
    signal border_done, border_trigger : std_logic;
    signal wait_counter : integer range 0 to 3;
begin
    border_gen: border_replicator
        generic map(IMG_WIDTH => SRC_W, IMG_HEIGHT => SRC_H, BORDER_SZ => BORDER_SIZE)
        port map(clk => clk, rst_n => rst_n, trigger => border_trigger,
                 src_img => src_data, bordered_img => bordered_src, complete => border_done);

    main_proc: process(clk, rst_n)
        type weight_array is array(0 to 5) of integer range -128 to 256;
        type accum_array is array(0 to 5) of integer;
        variable src_x_scaled, src_y_scaled, base_x, base_y, frac_x_scaled, frac_y_scaled : integer;
        variable kernel_h, kernel_v : weight_array;
        variable samples : img_buffer(0 to 5, 0 to 5);
        variable horiz_r, horiz_g, horiz_b : accum_array;
        variable accum_r, accum_g, accum_b, pixel_r, pixel_g, pixel_b : integer;
    begin
        if rst_n = '0' then
            state <= IDLE; finished <= '0'; border_trigger <= '0'; wait_counter <= 0;
        elsif rising_edge(clk) then
            case state is
                when IDLE =>
                    finished <= '0'; wait_counter <= 0;
                    if go = '1' then border_trigger <= '1'; state <= BORDER_PREP; end if;
                when BORDER_PREP =>
                    border_trigger <= '0';
                    if border_done = '1' then state <= CONVOLVE; end if;
                when CONVOLVE =>
                    for out_y in 0 to SRC_H*SCALE_FAC-1 loop
                        for out_x in 0 to SRC_W*SCALE_FAC-1 loop
                            src_x_scaled := ((out_x * SCALE + SCALE/2) / SCALE_FAC) - SCALE/2;
                            src_y_scaled := ((out_y * SCALE + SCALE/2) / SCALE_FAC) - SCALE/2;
                            base_x := src_x_scaled / SCALE; base_y := src_y_scaled / SCALE;
                            frac_x_scaled := src_x_scaled - (base_x * SCALE);
                            frac_y_scaled := src_y_scaled - (base_y * SCALE);
                            if frac_x_scaled < 0 then frac_x_scaled := frac_x_scaled + SCALE; base_x := base_x - 1; end if;
                            if frac_y_scaled < 0 then frac_y_scaled := frac_y_scaled + SCALE; base_y := base_y - 1; end if;
                            for idx in 0 to 5 loop
                                kernel_h(idx) := get_lanczos_weight(frac_x_scaled, idx);
                                kernel_v(idx) := get_lanczos_weight(frac_y_scaled, idx);
                            end loop;
                            for sy in 0 to 5 loop
                                for sx in 0 to 5 loop
                                    samples(sy, sx) := bordered_src(base_y + sy + 1, base_x + sx + 1);
                                end loop;
                            end loop;
                            for sy in 0 to 5 loop
                                accum_r := 0; accum_g := 0; accum_b := 0;
                                for sx in 0 to 5 loop
                                    accum_r := accum_r + samples(sy, sx).r * kernel_h(sx);
                                    accum_g := accum_g + samples(sy, sx).g * kernel_h(sx);
                                    accum_b := accum_b + samples(sy, sx).b * kernel_h(sx);
                                end loop;
                                horiz_r(sy) := (accum_r + SCALE/2) / SCALE;
                                horiz_g(sy) := (accum_g + SCALE/2) / SCALE;
                                horiz_b(sy) := (accum_b + SCALE/2) / SCALE;
                            end loop;
                            accum_r := 0; accum_g := 0; accum_b := 0;
                            for sy in 0 to 5 loop
                                accum_r := accum_r + horiz_r(sy) * kernel_v(sy);
                                accum_g := accum_g + horiz_g(sy) * kernel_v(sy);
                                accum_b := accum_b + horiz_b(sy) * kernel_v(sy);
                            end loop;
                            pixel_r := saturate((accum_r + SCALE/2) / SCALE);
                            pixel_g := saturate((accum_g + SCALE/2) / SCALE);
                            pixel_b := saturate((accum_b + SCALE/2) / SCALE);
                            output_buf(out_y, out_x).r <= pixel_r;
                            output_buf(out_y, out_x).g <= pixel_g;
                            output_buf(out_y, out_x).b <= pixel_b;
                        end loop;
                    end loop;
                    state <= OUTPUT_WAIT; wait_counter <= 0;
                when OUTPUT_WAIT =>
                    if wait_counter < 2 then wait_counter <= wait_counter + 1;
                    else dst_data <= output_buf; finished <= '1'; state <= COMPLETE; end if;
                when COMPLETE => state <= IDLE;
            end case;
        end if;
    end process main_proc;
end architecture rtl;
