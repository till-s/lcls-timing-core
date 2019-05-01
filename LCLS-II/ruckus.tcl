# Load RUCKUS library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

# Load Source Code
loadRuckusTcl "$::DIR_PATH/core"
loadRuckusTcl "$::DIR_PATH/evr"

# Get the family type
set family [getFpgaFamily]

if { ${family} == "kintexu" } {
   loadRuckusTcl "$::DIR_PATH/gthUltraScale"
}

if { ${family} == "kintexuplus" } {
   loadRuckusTcl "$::DIR_PATH/gtyUltraScale+"
}

if {   ${family} == "zynq"
    || ${family} == "artix7"
    || ${family} == "kintex7"
    || ${family} == "virtex7" } {
   loadRuckusTcl "$::DIR_PATH/7Series"
}
