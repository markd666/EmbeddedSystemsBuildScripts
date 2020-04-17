load("@AvrToolchain//platforms:avr_mcu_list.bzl", "mcu_list")

def get_mcu():
    options = {}
    for mcu in mcu_list:
        options["@AvrToolchain//platforms/mcu:{}_config".format(mcu)] = mcu
    options["//conditions:default"] = "none"
    return select(options)

def get_mcu_as_array():
    options = {}
    for mcu in mcu_list:
        options["@AvrToolchain//platforms/mcu:{}_config".format(mcu)] = [mcu]
    options["//conditions:default"] = []
    return select(options)
