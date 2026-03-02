#ifndef GENERATED_CONFIG_H
#define GENERATED_CONFIG_H
#include <string>
#include <iostream>
#include <vector>
#include <cstdlib>

struct Config {
    bool verbose = false;
    int threads = 4;
    size_t limit = 1024;
    std::string out = "output.txt";
    std::string input = "";
};

inline void print_help() {
    std::cout << "Usage: [options] [input]\n\n";
    std::cout << "Options:\n";
    std::cout << "    -v,  --verbose        Enable verbose logging (Default: false)\n";
    std::cout << "    -t,  --threads        Number of worker threads (Default: 4)\n";
    std::cout << "    -l,  --limit          Size limit in bytes (Default: 1024)\n";
    std::cout << "    -o,  --out            Output filename (Default: output.txt)\n";
}

inline void parse_args(Config& cfg, int argc, char** argv) {
    for (int i = 1; i < argc; ++i) {
        std::string arg = argv[i];
        if (arg == "--help" || arg == "-h") { print_help(); std::exit(0); }
        if ((arg == "--verbose" || arg == "-v")) { cfg.verbose = true; continue; }
        if ((arg == "--threads" || arg == "-t") && i + 1 < argc) {
            cfg.threads = std::stoi(argv[++i]); continue;
        }
        if ((arg == "--limit" || arg == "-l") && i + 1 < argc) {
            cfg.limit = std::stoul(argv[++i]); continue;
        }
        if ((arg == "--out" || arg == "-o") && i + 1 < argc) {
            cfg.out = argv[++i]; continue;
        }
        if (arg[0] != '-') {
            cfg.input = arg;
            continue;
        }
    }
}
#endif
