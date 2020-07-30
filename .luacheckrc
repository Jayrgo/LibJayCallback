-- luacheck: ignore
std = "lua51"
max_line_length = false
exclude_files = {".luacheckrc", ".luaformat"}
ignore = {
    "211", -- Unused local variable
    "212", -- Unused argument
}
globals = {"CopyTable", "format", "geterrorhandler", "LibStub", "strbyte", "strlen", "wipe"}
