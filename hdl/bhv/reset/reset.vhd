-----------------------------------------------------------------------------
-- file			: reset.vhd
--
-- brief		: Reset generator (for simulation)
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

entity reset is
	generic
	(
		clock_duration	: natural := 5
	);
	port
	(
		clock : in		std_ulogic;
		reset : out		std_ulogic
	);
end reset;

architecture bhv of reset is
	signal counter : natural;
begin

counter_gen: process(clock)
begin
	if rising_edge(clock) then
		if counter < clock_duration then
			counter <= counter + 1;
		end if;
	end if;
end process;

reset_gen: process(counter)
begin
	if counter < clock_duration then
		reset <= '1';
	else
		reset <= '0';
	end if;
end process;

end architecture bhv;
