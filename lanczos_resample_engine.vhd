-- Lanczos Engine - FINAL CORRECT VERSION
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
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
    constant KERNEL_SUPPORT : natural := 3;
    constant WINDOW_SIZE    : natural := 6;
    constant BORDER_SIZE    : natural := 3;  -- FIXED: Was 5, now 3

    function compute_sinc(x : real) return real is
        constant PI : real := MATH_PI;
    begin
        if abs(x) < 1.0e-5 then
            return 1.0;
        else
            return sin(PI * x) / (PI * x);
        end if;
    end function;

    function lanczos3_weight(dist : real) return real is
        variable abs_dist : real;
    begin
        abs_dist := abs(dist);
        if abs_dist >= 3.0 then
            return 0.0;
        else
            return compute_sinc(abs_dist) * compute_sinc(abs_dist / 3.0);
        end if;
    end function;

    function saturate(val : integer) return integer is
    begin
        if val > 255 then return 255;
        elsif val < 0 then return 0;
        else return val;
        end if;
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
        type weight_array is array(0 to 5) of real;
        type sample_array is array(0 to 5) of integer;
        variable src_x, src_y : real;
        variable base_x, base_y : integer;
        variable frac_x, frac_y : real;
        variable kernel_h, kernel_v : weight_array;
        variable samples : img_buffer(0 to 5, 0 to 5);
        variable horiz_r, horiz_g, horiz_b : sample_array;
        variable accum_r, accum_g, accum_b : real;
        variable pixel_r, pixel_g, pixel_b : integer;
    begin
        if rst_n = '0' then
            state <= IDLE;
            finished <= '0';
            border_trigger <= '0';
            wait_counter <= 0;
        elsif rising_edge(clk) then
            case state is
                when IDLE =>
                    finished <= '0';
                    wait_counter <= 0;
                    if go = '1' then
                        border_trigger <= '1';
                        state <= BORDER_PREP;
                    end if;

                when BORDER_PREP =>
                    border_trigger <= '0';
                    if border_done = '1' then
                        state <= CONVOLVE;
                    end if;

                when CONVOLVE =>
                    for out_y in 0 to SRC_H*SCALE_FAC-1 loop
                        for out_x in 0 to SRC_W*SCALE_FAC-1 loop
                            src_x := (real(out_x) + 0.5) / real(SCALE_FAC) - 0.5;
                            src_y := (real(out_y) + 0.5) / real(SCALE_FAC) - 0.5;
                            base_x := integer(floor(src_x));
                            base_y := integer(floor(src_y));
                            frac_x := src_x - real(base_x);
                            frac_y := src_y - real(base_y);

                            for idx in 0 to 5 loop
                                kernel_h(idx) := lanczos3_weight(real(idx - 2) - frac_x);
                                kernel_v(idx) := lanczos3_weight(real(idx - 2) - frac_y);
                            end loop;

                            -- FINAL FIX: BORDER_SIZE=3, offset=+1
                            -- Window samples: base-2, base-1, base, base+1, base+2, base+3
                            -- Formula: (base + sx - 2) + BORDER_SIZE = base + sx + 1
                            for sy in 0 to 5 loop
                                for sx in 0 to 5 loop
                                    samples(sy, sx) := bordered_src(base_y + sy + 1, 
                                                                     base_x + sx + 1);
                                end loop;
                            end loop;

                            for sy in 0 to 5 loop
                                accum_r := 0.0;
                                accum_g := 0.0;
                                accum_b := 0.0;
                                for sx in 0 to 5 loop
                                    accum_r := accum_r + real(samples(sy, sx).r) * kernel_h(sx);
                                    accum_g := accum_g + real(samples(sy, sx).g) * kernel_h(sx);
                                    accum_b := accum_b + real(samples(sy, sx).b) * kernel_h(sx);
                                end loop;
                                horiz_r(sy) := saturate(integer(round(accum_r)));
                                horiz_g(sy) := saturate(integer(round(accum_g)));
                                horiz_b(sy) := saturate(integer(round(accum_b)));
                            end loop;

                            accum_r := 0.0;
                            accum_g := 0.0;
                            accum_b := 0.0;
                            for sy in 0 to 5 loop
                                accum_r := accum_r + real(horiz_r(sy)) * kernel_v(sy);
                                accum_g := accum_g + real(horiz_g(sy)) * kernel_v(sy);
                                accum_b := accum_b + real(horiz_b(sy)) * kernel_v(sy);
                            end loop;

                            pixel_r := saturate(integer(round(accum_r)));
                            pixel_g := saturate(integer(round(accum_g)));
                            pixel_b := saturate(integer(round(accum_b)));

                            output_buf(out_y, out_x).r <= pixel_r;
                            output_buf(out_y, out_x).g <= pixel_g;
                            output_buf(out_y, out_x).b <= pixel_b;
                        end loop;
                    end loop;
                    state <= OUTPUT_WAIT;
                    wait_counter <= 0;

                when OUTPUT_WAIT =>
                    if wait_counter < 2 then
                        wait_counter <= wait_counter + 1;
                    else
                        dst_data <= output_buf;
                        finished <= '1';
                        state <= COMPLETE;
                    end if;

                when COMPLETE =>
                    state <= IDLE;
            end case;
        end if;
    end process main_proc;
end architecture rtl;
