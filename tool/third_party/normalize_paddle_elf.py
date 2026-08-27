#!/usr/bin/env python3

import argparse
import os
import struct
from pathlib import Path


BOUNDARY_SYMBOLS = {
    "_edata",
    "__end__",
    "__bss_end__",
    "_bss_end__",
    "__bss_start__",
    "_end",
    "__bss_start",
}

# NOTE(ceiling): This only repairs the known Paddle boundary-symbol metadata;
# replace the runtime with an unmodified compatible upstream build when one exists.


def section_layout(data: bytearray) -> tuple[str, int, int, int]:
    if data[:4] != b"\x7fELF" or data[5] != 1:
        raise ValueError("Expected a little-endian ELF file")
    if data[4] == 2:
        header = struct.unpack_from("<HHIQQQIHHHHHH", data, 16)
        return "<IIQQQQIIQQ", header[5], header[10], header[11]
    if data[4] == 1:
        header = struct.unpack_from("<HHIIIIIHHHHHH", data, 16)
        return "<IIIIIIIIII", header[5], header[10], header[11]
    raise ValueError("Unsupported ELF class")


def normalize(source: Path, destination: Path) -> None:
    data = bytearray(source.read_bytes())
    section_format, section_offset, section_size, section_count = section_layout(data)
    sections = [
        struct.unpack_from(section_format, data, section_offset + index * section_size)
        for index in range(section_count)
    ]
    dynsym = next((section for section in sections if section[1] == 11), None)
    if dynsym is None:
        raise ValueError("Missing dynamic symbol table")
    dynstr = sections[dynsym[6]]
    symbol_offset, symbol_size, symbol_entry_size = dynsym[4], dynsym[5], dynsym[9]
    string_offset = dynstr[4]
    info_offset = 4 if data[4] == 2 else 12
    found = set()

    for offset in range(symbol_offset, symbol_offset + symbol_size, symbol_entry_size):
        name_offset = struct.unpack_from("<I", data, offset)[0]
        name_start = string_offset + name_offset
        name_end = data.index(0, name_start)
        name = data[name_start:name_end].decode("utf-8")
        if name not in BOUNDARY_SYMBOLS:
            continue
        info = data[offset + info_offset]
        binding = info >> 4
        if binding not in (0, 1) or info & 0x0F != 0:
            raise ValueError(f"Unexpected binding or type for {name}")
        if binding == 0:
            data[offset + info_offset] = 0x10
        found.add(name)

    if not found:
        raise ValueError("Missing expected boundary symbols")

    temporary = destination.with_suffix(destination.suffix + ".tmp")
    temporary.parent.mkdir(parents=True, exist_ok=True)
    temporary.write_bytes(data)
    os.replace(temporary, destination)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("destination", type=Path)
    arguments = parser.parse_args()
    normalize(arguments.source, arguments.destination)


if __name__ == "__main__":
    main()
