# vunit test benches

 * All tb_*.vhd and *_tb.vhd files in the subdirectories will be run against vunit
 * Files in the ../../hdl subdirectories are compiled and available for vunit
 * Entities ending with _tbc will be tested with and without a clock, see the
   example : [00_test_vunit/tb_vunit_tbc.vhd](00_test_vunit/tb_vunit_tbc.vhd).