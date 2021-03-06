-----------------------------------------------------------------------------
-- FIXME : add boards to the lib
-----------------------------------------------------------------------------
-- brief		: Test bench
-- author(s)	: marc at pignat dot org
-----------------------------------------------------------------------------
-- Copyright 2015-2019 Marc Pignat
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
-- 		http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- See the License for the specific language governing permissions and
-- limitations under the License.
-----------------------------------------------------------------------------

library ieee;
	use ieee.std_logic_1164.all;
	use ieee.numeric_std.all;

entity tb_f245_03_counter_to_host_tbc is
	generic
	(
		runner_cfg		: string;
		g_reset_enable	: boolean := false
	);
end entity;

architecture bhv of tb_f245_03_counter_to_host_tbc is
	signal clock			: std_ulogic;
	signal reset			: std_ulogic;
	signal done				: std_ulogic;
	constant bug_severity	: severity_level := failure;
	constant g_nrdata_log2	: natural := 7;

	signal adbus			: std_logic_vector(7 downto 0);
	signal txe_n			: std_ulogic;
	signal rxf_n			: std_ulogic;
	signal wr_n				: std_ulogic;
	signal rd_n				: std_ulogic;
	signal oe_n				: std_ulogic;
	signal siwu				: std_ulogic;
	signal suspend_n		: std_ulogic;
	signal reset_n			: std_ulogic;
	signal d_counter		: unsigned(7 downto 0) := (others => '0');
	signal d_data_in		: std_ulogic_vector(7 downto 0);
	signal d_data_write		: std_ulogic;
	signal d_data_full		: std_ulogic;
	signal read_data		: std_ulogic_vector(7 downto 0);
	signal write_data		: std_ulogic_vector(7 downto 0);
	signal write_read		: std_ulogic;
	signal read_valid		: std_ulogic;

	signal counter			: unsigned(7 downto 0);
	signal counter_valid	: std_ulogic;
	signal d_data_out		: std_ulogic_vector(7 downto 0);
	signal d_data_out_valid : std_ulogic;
	signal out_data			: std_ulogic_vector(7 downto 0);
	signal out_valid		: std_ulogic;

	signal expected_data	: std_ulogic_vector(7 downto 0);
begin

	i_vunit_tbc: entity work.vunit_tbc
	generic map
	(
		g_frequency		=> 60.0e6,
		g_runner_cfg	=> runner_cfg,
		g_reset_enable	=> g_reset_enable
	)
	port map
	(
		clock		=> clock,
		reset		=> reset,
		done		=> done
	);

tb_proc: process
	variable timeout : integer;
	begin
	done <= '0';
	wait until reset = '0';

	expected_data <= (others => '0');

	for i in 0 to 1000 loop

		timeout := 100;
		while out_valid /= '1' loop
			wait until falling_edge(clock);

			assert timeout > 0 report "Timeout waiting for out_valid" severity bug_severity;

			timeout := timeout - 1;
		end loop;

		while out_valid = '1' loop

			assert out_data = expected_data report "Wrong data out_data:" &integer'image(to_integer(unsigned(out_data))) &" expected : " &integer'image(to_integer(unsigned(expected_data))) severity bug_severity;
			expected_data <= std_ulogic_vector(unsigned(expected_data) + 1);
			wait until falling_edge(clock);
		end loop;

	end loop;

	done <= '1';

	wait;

end process;

i_top : entity work.top_mimas_ft245_counter
generic map
(
	g_nrdata_log2	=> g_nrdata_log2
)
port map
(
	adbus		=> adbus,
	rxf_n		=> rxf_n,
	txe_n		=> txe_n,
	rd_n		=> rd_n,
	wr_n		=> wr_n,
	clkout		=> clock,
	oe_n		=> oe_n,
	siwu		=> siwu,
	reset_n		=> reset_n,
	suspend_n	=> suspend_n,

	reset		=> reset
);

i_ft_sim : entity work.ft245_sync_sim
generic map
(
	g_to_host_depth_log2 => 3
)
port map
(
	adbus				=> adbus,
	rxf_n				=> rxf_n,
	txe_n				=> txe_n,
	rd_n				=> rd_n,
	wr_n				=> wr_n,
	clock				=> clock,
	oe_n				=> oe_n,
	siwu				=> siwu,
	reset_n				=> reset_n,
	suspend_n			=> suspend_n,

	d_data_in			=> d_data_in,
	d_data_write		=> d_data_write,
	d_data_full			=> d_data_full,

	d_data_out			=> d_data_out,
	d_data_out_valid	=> d_data_out_valid
);

i_depacketizer : entity work.depacketizer
generic map
(
	g_nrdata_log2		=> g_nrdata_log2
)
port map
(
	clock			=> clock,
	reset			=> reset,

	in_data			=> d_data_out,
	in_valid		=> d_data_out_valid,

	out_data		=> out_data,
	out_valid		=> out_valid
);

d_data_in		<= std_ulogic_vector(d_counter) when d_data_write = '1' else (others => '-');
d_data_write	<= not d_data_full when d_counter = 11 else '0';

process(reset, clock)
begin
	if reset = '1' then
		d_counter <= (others => '0');
	elsif rising_edge(clock) then
		d_counter <= d_counter + 1;
	end if;
end process;

end architecture;
