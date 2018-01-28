package = "moan"
version = "1.0-1"
source = {
    url = "git://github.com/insideone/Moan.lua",
    tag = "1.0.1"
}
description = {
    summary = "A messagebox library with multiple-choices for LÖVE",
    detailed = [[
        A messagebox library with multiple-choices for LÖVE
    ]],
    homepage = "https://github.com/twentytwoo/Moan.lua",
    license = "MIT"
}
dependencies = {
    "lua >= 5.0"
}
build = {
    type = "builtin",
    modules = {
        Moan = "Moan.lua"
    },
    copy_directories = {"assets"}
}
