-----------------------------------------------------------------------------
-- file			: ft245_sync_if.vhd
--
-- brief		: Interface for FTDI ft2232h in ft245 synchronous mode
-- author(s)	: marc at pignat dot org
-----------------------------------------------------------------------------
-- Copyright 2015,2016 Marc Pignat
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
--
-- FIXME	: loose bytes when using ftdi_set_latency_timer(ftdi, 0), so
--			  use ftdi_set_latency_timer(ftdi, 2).
--
-----------------------------------------------------------------------------
library ieee;
	use ieee.std_logic_1164.all;
	use ieee.numeric_std.all;

entity ft245_sync_if is
port
(
	-- Interface to the ftdi chip
	adbus			: inout	std_logic_vector(7 downto 0);
	rxf_n			: in	std_ulogic;
	txe_n			: in	std_ulogic;
	rd_n			: out	std_ulogic;
	wr_n			: out	std_ulogic;
	clock			: in	std_ulogic;
	oe_n			: out	std_ulogic;
	siwu			: out	std_ulogic;
	reset_n			: out	std_ulogic;
	suspend_n		: in	std_ulogic;

	-- Interface to the internal logic
	reset			: in	std_ulogic;

	in_data			: in	std_ulogic_vector(7 downto 0);
	in_empty		: in	std_ulogic;
	in_read			: out	std_ulogic;

	out_data		: out	std_ulogic_vector(7 downto 0);
	out_valid		: out	std_ulogic
);

	-- Force signals into IO pads
	-- Warning XST specific syntax
	attribute iob				: string;
	attribute iob of rxf_n		: signal is "FORCE";
	attribute iob of txe_n		: signal is "FORCE";
	attribute iob of rd_n		: signal is "FORCE";
	attribute iob of wr_n		: signal is "FORCE";
	attribute iob of oe_n		: signal is "FORCE";
	attribute iob of siwu		: signal is "FORCE";
	attribute iob of reset_n	: signal is "FORCE";
	attribute iob of suspend_n	: signal is "FORCE";

end ft245_sync_if;

architecture rtl of ft245_sync_if is

	type state_e is
	(
		STATE_RESET,
		STATE_IDLE,
		STATE_WAIT_READ1,
		STATE_WAIT_READ2,
		STATE_READ,
		STATE_AFTER_READ1,
		STATE_AFTER_READ2,
		STATE_WRITE,
		STATE_WRITE_OLD
	);

	-- State
	signal state			: state_e;
	signal next_state		: state_e;

	-- Positive versions of ft245 control signals
	signal ft_oe			: std_ulogic;
	signal ft_write			: std_ulogic;
	signal ft_read			: std_ulogic;
	signal ft_suspend		: std_ulogic;
	signal ft_tx			: std_ulogic;
	signal ft_rx			: std_ulogic;


	-- Data RX
	signal oe				: std_ulogic;
	signal adbus_int		: std_ulogic_vector(in_data'range);
	signal ft_read_old		: std_ulogic_vector(1 downto 0);
	signal out_data_int		: std_ulogic_vector(in_data'range);
	signal out_valid_int	: std_ulogic;

	-- Data TX
	type old_elem_t is
	record
		data	: std_ulogic_vector(in_data'range);
		valid	: std_ulogic;
		failed	: std_ulogic;
	end record;

	type old_t is array(2 downto 0) of old_elem_t;
	signal ft_write_old		: std_ulogic_vector(1 downto 0);
	signal write_failed		: std_ulogic;
	signal in_data_old		: old_t;
	signal old_counter		: unsigned(1 downto 0);
	signal in_read_int		: std_ulogic;
	signal in_read_old		: std_ulogic;

	-- Force signals into IO pads
	-- Warning XST specific syntax
	attribute iob of adbus_int		: signal is "FORCE";
	attribute iob of ft_rx			: signal is "FORCE";
	attribute iob of ft_tx			: signal is "FORCE";
	attribute iob of ft_suspend		: signal is "FORCE";

begin

-----------------------------------------------------------------------------
-- Ports
-----------------------------------------------------------------------------

-- When the ft2232h is resest, it will exit the synchronous fifo mode
reset_n <= '1';

-- Unused output
siwu <= '1';

-- Tristate
adbus <= std_logic_vector(adbus_int) when oe = '1' else (others => 'Z');

-- Synchronize input signals
in_sync: process(reset, clock)
begin
	if reset = '1' then
		out_data_int	<= (others => '0');
		ft_tx			<= '0';
		ft_rx			<= '0';
		ft_suspend		<= '0';
	elsif rising_edge(clock) then
		out_data_int	<= std_ulogic_vector(adbus);
		ft_tx			<= not txe_n;
		ft_rx			<= not rxf_n;
		ft_suspend		<= not suspend_n;
	end if;
end process;

-- Synchronize output signals
out_sync: process(reset, clock)
begin
	if reset = '1' then
		adbus_int	<= (others => '0');
		rd_n			<= '1';
		wr_n			<= '1';
		oe_n			<= '1';
	elsif rising_edge(clock) then
		adbus_int		<= in_data;
		rd_n			<= not ft_read;
		wr_n			<= not ft_write;
		oe_n			<= not ft_oe;
		if state = STATE_WRITE_OLD then
			adbus_int <= in_data_old(in_data_old'left).data;
		end if;
	end if;
end process;

-----------------------------------------------------------------------------
-- State machine
-----------------------------------------------------------------------------

state_machine: process(reset, clock)
begin
	if reset = '1' then
		state <= STATE_RESET;
	elsif rising_edge(clock) then
		state <= next_state;
	end if;
end process;

state_machine_next: process(state, in_empty, ft_rx, ft_tx, write_failed, ft_write, old_counter)
begin
	next_state <= state;

	case state is
		when STATE_RESET =>
			next_state <= STATE_IDLE;

		when STATE_IDLE =>
			if in_empty = '0' and ft_tx = '1' then
				next_state <= STATE_WRITE;
			end if;

			if write_failed = '1' and ft_tx = '1' then
				next_state <= STATE_WRITE_OLD;
			end if;

			if ft_rx = '1' then
				next_state <= STATE_WAIT_READ1;
			end if;

		when STATE_WAIT_READ1 =>
			next_state <= STATE_WAIT_READ2;

		when STATE_WAIT_READ2 =>
			next_state <= STATE_READ;

		when STATE_READ =>
			if ft_rx = '0' then
				next_state <= STATE_AFTER_READ1;
			end if;

		when STATE_AFTER_READ1 =>
			next_state <= STATE_AFTER_READ2;
		when STATE_AFTER_READ2 =>
			next_state <= STATE_IDLE;

		when STATE_WRITE_OLD =>
			if old_counter = in_data_old'left then
				next_state <= STATE_IDLE;
			end if;

		when STATE_WRITE =>
			if ft_tx = '1' and in_empty = '0' then
				next_state <= STATE_WRITE;
			else
				next_state <= STATE_IDLE;
			end if;
	end case;
end process;


-- ft_oe and oe are not driven simultaneously to avoid bus contention.
with state select ft_oe <=
		'1' when STATE_WAIT_READ1 | STATE_WAIT_READ2 | STATE_READ,
		'0' when others;

with state select oe <=
		'0' when STATE_WAIT_READ1 | STATE_WAIT_READ2 | STATE_READ | STATE_AFTER_READ1 | STATE_AFTER_READ2,
		'1' when others;

with state select ft_read <=
		'1' when STATE_WAIT_READ2 | STATE_READ,
		'0' when others;

with state select ft_write <=
		ft_tx when STATE_WRITE,
		in_data_old(in_data_old'left).failed when STATE_WRITE_OLD,
		'0' when others;

in_read <= in_read_int;
with next_state select in_read_int <=
		ft_tx when STATE_WRITE,
		'0' when others;

-----------------------------------------------------------------------------
-- RX data
-----------------------------------------------------------------------------

old_rx: process(reset, clock)
begin
	if reset = '1' then
		for i in ft_read_old'range loop
			ft_read_old(i) <= '0';
		end loop;
	elsif rising_edge(clock) then
		for i in ft_read_old'left downto 1 loop
			ft_read_old(i) <= ft_read_old(i-1);
		end loop;
		ft_read_old(0)	<= ft_read;
	end if;
end process;

out_valid <= out_valid_int;
out_valid_int <= ft_read_old(1) and ft_rx;

out_data_proc: process(out_data_int, out_valid_int)
begin
	out_data <= out_data_int;

	--pragma synthesis_off
	if out_valid_int = '0' then
		out_data <= (others => '-');
	end if;
	--pragma synthesis_on

end process;

-----------------------------------------------------------------------------
-- TX data
-----------------------------------------------------------------------------

old_tx: process(reset, clock)
begin
	if reset = '1' then
		for i in ft_write_old'range loop
			ft_write_old(i) <= '0';
		end loop;
	elsif rising_edge(clock) then
		for i in ft_write_old'left downto 1 loop
			ft_write_old(i) <= ft_write_old(i-1);
		end loop;
		ft_write_old(0)	<= ft_write;
	end if;
end process;

in_read_old_proc: process(reset, clock)
begin
	if reset = '1' then
		in_read_old			<= '0';
	elsif rising_edge(clock) then
		in_read_old			<= in_read_int;
	end if;
end process;

process(reset, clock)
begin
	if reset = '1' then
		for i in in_data_old'range loop
			in_data_old(i).data	 <= (others => '0');
			in_data_old(i).failed <= '0';

			--pragma synthesis_off
			in_data_old(i).data <= (others => '-');
			--pragma synthesis_on

		end loop;

		old_counter <= (others => '0');
		write_failed<= '0';
	elsif rising_edge(clock) then

		if write_failed = '0' then
			for i in in_data_old'left downto 1 loop
				in_data_old(i)		<= in_data_old(i-1);
			end loop;
			in_data_old(0).data		<= in_data;
			in_data_old(0).valid		<= in_read_old;
			in_data_old(0).failed	<= '0';

		end if;

		if ft_write_old(1) = '1' and ft_tx = '0' then
			write_failed <= '1';
		end if;

		if write_failed = '1' then
			for i in in_data_old'left downto 0 loop
				in_data_old(i).failed <= in_data_old(i).valid;
			end loop;
		end if;

		if state = STATE_WRITE_OLD then
			old_counter <= old_counter + 1;
			for i in in_data_old'left downto 1 loop
				in_data_old(i) <= in_data_old(i-1);
			end loop;

			in_data_old(0).failed <= '0';
			in_data_old(0).valid <= '0';

			--pragma synthesis_off
			in_data_old(0).data <= (others => '-');
			--pragma synthesis_on

			if next_state = STATE_IDLE then
				old_counter <= (others => '0');
				write_failed <= '0';
			end if;
		end if;
	end if;
end process;

end rtl;
