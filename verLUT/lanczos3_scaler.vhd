-- Top-Level Scaler (VHDL-93)
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.img_types.all;

entity lanczos3_scaler is
    generic(WIDTH : natural := 100; HEIGHT : natural := 100; SCALE : natural := 2);
    port(clock : in std_logic; reset_n : in std_logic; start_proc : in std_logic; end_proc : in std_logic;
         input_img : in img_buffer(0 to WIDTH-1, 0 to HEIGHT-1);
         output_img : out img_buffer(0 to WIDTH*SCALE-1, 0 to HEIGHT*SCALE-1);
         status : out std_logic_vector(1 downto 0); proc_done : out std_logic; sys_ready : out std_logic);
end entity lanczos3_scaler;

architecture structural of lanczos3_scaler is
    component lanczos_resample_engine is
        generic(SRC_W : natural; SRC_H : natural; SCALE_FAC : natural);
        port(clk : in std_logic; rst_n : in std_logic; go : in std_logic;
             src_data : in img_buffer(0 to SRC_W-1, 0 to SRC_H-1);
             dst_data : out img_buffer(0 to SRC_W*SCALE_FAC-1, 0 to SRC_H*SCALE_FAC-1);
             finished : out std_logic);
    end component;
    type system_mode is (STANDBY, PROCESSING, DONE_STATE);
    signal mode : system_mode;
    signal engine_go, engine_done : std_logic;
    signal img_buffer_in : img_buffer(0 to WIDTH-1, 0 to HEIGHT-1);
begin
    scaler_core: lanczos_resample_engine
        generic map(SRC_W => WIDTH, SRC_H => HEIGHT, SCALE_FAC => SCALE)
        port map(clk => clock, rst_n => reset_n, go => engine_go,
                 src_data => img_buffer_in, dst_data => output_img, finished => engine_done);

    controller: process(clock, reset_n)
    begin
        if reset_n = '0' then
            mode <= STANDBY; status <= "00";
        elsif rising_edge(clock) then
            case mode is
                when STANDBY =>
                    sys_ready <= '1'; proc_done <= '0'; engine_go <= '0'; status <= "00";
                    for row in 0 to WIDTH-1 loop
                        for col in 0 to HEIGHT-1 loop
                            img_buffer_in(row, col).r <= 0;
                            img_buffer_in(row, col).g <= 0;
                            img_buffer_in(row, col).b <= 0;
                        end loop;
                    end loop;
                    if start_proc = '1' then
                        img_buffer_in <= input_img; engine_go <= '1'; status <= "01"; mode <= PROCESSING;
                    end if;
                when PROCESSING =>
                    if engine_done = '1' then engine_go <= '0'; status <= "10"; mode <= DONE_STATE; end if;
                when DONE_STATE =>
                    sys_ready <= '0'; proc_done <= '1';
                    if end_proc = '1' then status <= "00"; mode <= STANDBY; end if;
            end case;
        end if;
    end process controller;
end architecture structural;
