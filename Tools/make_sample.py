# Extrae del volcado de dump_reference.py una muestra pequeña para versionar en los tests:
# hasta PER_BIT claves por cada (estructura, orientación) que cumple la referencia en Python
# y RANDOM claves al azar (reproducible). Formato de texto: "blancas negras máscara" en hex.
#
#   python3 Tools/make_sample.py REFERENCIA.bin Tests/ChessPawnStructuresTests/Resources/reference-sample.txt
import random, struct, sys

PER_BIT, RANDOM = 40, 1500
src, dst = sys.argv[1], sys.argv[2]
with open(src, "rb") as f:
    data = f.read()
assert data[:4] == b"PSR1"
n = struct.unpack_from("<I", data, 4)[0]
keys = [struct.unpack_from("<QQQ", data, 8 + 24 * i) for i in range(n)]

rng = random.Random(16112026)
chosen = {}
by_bit = {}
for k in keys:
    m = k[2]
    while m:
        bit = (m & -m).bit_length() - 1
        by_bit.setdefault(bit, []).append(k)
        m &= m - 1
for bit, ks in sorted(by_bit.items()):
    for k in rng.sample(ks, min(PER_BIT, len(ks))):
        chosen[(k[0], k[1])] = k[2]
for k in rng.sample(keys, RANDOM):
    chosen[(k[0], k[1])] = k[2]

with open(dst, "w") as out:
    out.write(f"# {len(chosen)} claves de peones con la clasificación de la referencia en Python\n")
    out.write("# blancas negras máscara (hex; bit = (NN - 1) * 2 + invertida)\n")
    for (w, b), m in sorted(chosen.items()):
        out.write(f"{w:016x} {b:016x} {m:016x}\n")
print(f"{len(chosen)} claves; estructuras con muestra: {len(by_bit)}")
