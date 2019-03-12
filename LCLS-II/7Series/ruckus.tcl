# Load RUCKUS environment and library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

if { $::env(VIVADO_VERSION) >= 2016.4 } {

   # There are many different 7-series devices and 'dcp' or 'xci' files are
   # not portable among them. Even two similar zynq devices wouldn't allow me
   # to share the 'xci'. Vivado then automatically converts to the new device
   # but does a *terrible* job. The IP updater warns that some settings couldn't
   # be preserved but almost *nothing* is.
   # Thus, we use TCL to create and personalize the IP...
   if { [ regexp "XC7Z(030|045).*" [string toupper "$::env(PRJ_PART)"] ] } {
      if { [llength [get_ips TimingGtx]] == 0 } {
         source "$::DIR_PATH/coregen/genTimingGtx.tcl"
      }

      loadSource -path "$::DIR_PATH/rtl/TimingGtxCoreWrapper.vhd"

   } elseif { [ regexp "XC7Z(012|015).*" [string toupper "$::env(PRJ_PART)"] ] } {
      if { [llength [get_ips TimingGtp]] == 0 } {
         source "$::DIR_PATH/coregen/genTimingGtp.tcl"
      }

      loadSource -path "$::DIR_PATH/rtl/TimingGtpCoreWrapper.vhd"
      loadSource -path "$::DIR_PATH/rtl/timinggtp_common.vhd"
      loadSource -path "$::DIR_PATH/rtl/timinggtp_cpll_railing.vhd"

   }

} else {
   puts "\n\nWARNING: $::DIR_PATH requires Vivado 2016.4 (or later)\n\n"
}  
