#!/usr/bin/awk -f

BEGIN {
    print "#ifndef GENERATED_CONFIG_H"
    print "#define GENERATED_CONFIG_H"
    print "#include <string>\n#include <iostream>\n#include <vector>\n#include <cstdlib>\n"
    print "struct Config {"
    used_shorts["h"] = "help"
}

# skip comments and empty lines
/^[ \t]*#/ || /^[ \t]*$/ { next }

{
    type = $1; name = $2; def = $3;
    
    # capture description text (stripping quotes)
    if (match($0, /"[^"]*"/)) {
        desc = substr($0, RSTART + 1, RLENGTH - 2);
    }

    # handle the optional positional filename
    if (def == "POSITIONAL") {
        pos_name = name;
        pos_desc = desc;
        next;
    }

    count++;
    types[count] = type; names[count] = name; defs[count] = def; descs[count] = desc;
    
    # Short flag logic
    s = substr(name, 1, 1);
    if (!(s in used_shorts)) {
        used_shorts[s] = name;
        shorts[count] = "-" s;
    }
    longs[count] = "--" name;

    print "    " type " " name " = " def ";"
}

END {
    if (pos_name) {
        print "    std::string " pos_name " = \"\";";
    }
    print "};\n"
    
    print "inline void print_help() {"
    if (pos_name) {
        printf "    std::cout << \"Usage: [options] [%s]\\n\\n\";\n", pos_name;
    }
    print "    std::cout << \"Options:\\n\";"
    for (i = 1; i <= count; i++) {
        prefix = (shorts[i] != "") ? sprintf("  %s,  ", shorts[i]) : "       ";
        printf "    std::cout << \"  %s%-16s %s (Default: %s)\\n\";\n", \
            prefix, longs[i], descs[i], defs[i]
    }
    print "}\n"

    print "inline void parse_args(Config& cfg, int argc, char** argv) {"
    print "    for (int i = 1; i < argc; ++i) {"
    print "        std::string arg = argv[i];"
    print "        if (arg == \"--help\" || arg == \"-h\") { print_help(); std::exit(0); }"

    for (i = 1; i <= count; i++) {
        cond = (shorts[i] != "") ? \
               sprintf("(arg == \"%s\" || arg == \"%s\")", longs[i], shorts[i]) : \
               sprintf("(arg == \"%s\")", longs[i])

        if (types[i] == "bool") {
            printf "        if (%s) { cfg.%s = true; continue; }\n", cond, names[i]
        } else {
            printf "        if (%s && i + 1 < argc) {\n", cond
            if (types[i] == "size_t")      conv = "std::stoul(argv[++i])"
            else if (types[i] == "double") conv = "std::stod(argv[++i])"
            else if (types[i] == "int")    conv = "std::stoi(argv[++i])"
            else                           conv = "argv[++i]"
            printf "            cfg.%s = %s; continue;\n        }\n", names[i], conv
        }
    }

    if (pos_name) {
        print "        if (arg[0] != \x27-\x27) {"
        print "            cfg." pos_name " = arg;"
        print "            continue;"
        print "        }"
    }
    print "    }\n}\n#endif"
}
