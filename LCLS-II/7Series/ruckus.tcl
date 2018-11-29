# Load RUCKUS environment and library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

if { $::env(VIVADO_VERSION) >= 2016.4 } {

   loadSource -dir "$::DIR_PATH/rtl"

   #loadSource   -path "$::DIR_PATH/coregen/TimingGtx.dcp"
   loadIpCore -path "$::DIR_PATH/coregen/TimingGtx.xci"
   loadIpCore -path "$::DIR_PATH/coregen/TimingGtp.xci"

} else {
   puts "\n\nWARNING: $::DIR_PATH requires Vivado 2016.4 (or later)\n\n"
}  
   
