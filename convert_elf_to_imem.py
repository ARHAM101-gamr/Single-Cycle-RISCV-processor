import struct
from pathlib import Path

elf_path = Path('addmul.elf')
output_path = Path('imem.hex')

if not elf_path.exists():
    raise SystemExit('addmul.elf not found')

with open(elf_path, 'rb') as f:
    hdr = f.read(52)
    if hdr[:4] != b'\x7fELF':
        raise SystemExit('not an ELF file')
    elfclass = hdr[4]
    data = hdr[5]
    if elfclass != 1:
        raise SystemExit('unsupported ELF class: {}'.format(elfclass))
    endian = '<' if data == 1 else '>'
    e_type, e_machine, e_version, e_entry, e_phoff, e_shoff, e_flags, e_ehsize, e_phentsize, e_phnum, e_shentsize, e_shnum, e_shstrndx = struct.unpack(endian + 'HHLLLLLHHHHHH', hdr[16:52])
    print(f'ELF machine={hex(e_machine)} phnum={e_phnum} phoff={e_phoff} phentsize={e_phentsize}')
    if e_phoff == 0 or e_phnum == 0:
        raise SystemExit('no program headers')

    f.seek(e_phoff)
    segments = []
    for i in range(e_phnum):
        ph = f.read(e_phentsize)
        p_type, p_offset, p_vaddr, p_paddr, p_filesz, p_memsz, p_flags, p_align = struct.unpack(endian + 'LLLLLLLL', ph[:32])
        segments.append((p_type, p_offset, p_vaddr, p_filesz, p_memsz, p_flags, p_align))

    load_segments = [seg for seg in segments if seg[0] == 1 and seg[4] > 0]
    if not load_segments:
        raise SystemExit('no loadable segments')

    memory = {}
    for p_type, p_offset, p_vaddr, p_filesz, p_memsz, p_flags, p_align in load_segments:
        f.seek(p_offset)
        data_bytes = f.read(p_filesz)
        print(f'LOAD seg vaddr={hex(p_vaddr)} filesz={p_filesz} memsz={p_memsz} flags={p_flags}')
        for i, b in enumerate(data_bytes):
            addr = p_vaddr + i
            memory[addr] = b

    if not memory:
        raise SystemExit('no bytes loaded')

    min_addr = min(memory)
    max_addr = max(memory)
    if max_addr >= 256:
        print(f'WARNING: loaded bytes cover 0x{max_addr:02x}, which is outside 256-byte imem size')

    with open(output_path, 'w') as out:
        current_addr = None
        byte_count = 0
        out.write('@00000000\n')
        for addr in range(min_addr, max_addr + 1):
            if addr not in memory:
                out.write('00 ')
            else:
                if current_addr is None:
                    current_addr = addr
                out.write(f'{memory[addr]:02x} ')
                byte_count += 1
                if (addr - min_addr + 1) % 16 == 0:
                    out.write('\n')
        if byte_count % 16 != 0:
            out.write('\n')

    print(f'Wrote {byte_count} bytes to {output_path} (range 0x{min_addr:02x}-0x{max_addr:02x})')
