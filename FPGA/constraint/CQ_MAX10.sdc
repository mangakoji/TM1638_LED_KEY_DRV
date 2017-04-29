# ------------------------------------------
# Create generated clocks based on PLLs
# ------------------------------------------

#derive_pll_clocks



# ------------------------------------------
# Original Clock Setting
# ------------------------------------------

#create_clock -period "20.000 ns" -name {CLOCK_50_2} {CLOCK_50_2}
#create_clock -period "20.000 ns" -name {CLOCK_50} {CLOCK_50}
#
#set_clock_groups -asynchronous \
#	-group { \
#	 	CLOCK_50 \
#	} \
#	-group { \
#		CLOCK_50_2 \
#	} \



# ------------------------------------------
# User Clock Setting
# ------------------------------------------

create_clock -period "20.833 ns" -name {CK_48M} {CK48M_i}


# ---------------------------------------------
