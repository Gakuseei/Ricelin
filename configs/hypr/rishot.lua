local rishot = os.getenv("HOME") .. "/.local/bin/rishot"

hl.bind("Print",        hl.dsp.exec_cmd(rishot))
hl.bind("SHIFT + Print", hl.dsp.exec_cmd(rishot .. " monitor"))
