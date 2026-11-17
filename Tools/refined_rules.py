# Reglas de referencia en Python para las dos estructuras de la Española afinadas en 0.1.1
# (Ruy López cerrada y Formación López). Sustituyen a las de RULES.py en esos dos bits.
#
#   python3 Tools/refined_rules.py ENTRADA.bin SALIDA.bin   # parchea un volcado PSR1 ya hecho
#
# dump_reference.py también las aplica al volcar, así que los volcados nuevos ya salen parcheados.
import struct, sys

def _sq(name):
    return 1 << ((int(name[1]) - 1) * 8 + "abcdefgh".index(name[0]))

def _has(bb, *groups):
    # Cada grupo es "d5" o "c4|c5": al menos una de sus casillas con peón.
    return all(any(bb & _sq(x) for x in g.split("|")) for g in groups)

def _flip(b):
    return int.from_bytes(b.to_bytes(8, "little")[::-1], "little")

def closed_ruy_lopez(w, b):
    # Blancas c3 d5 e4; negras d6 e5 y el peón c en c4 o c5 (…b5 ya no se exige).
    return _has(w, "c3", "d5", "e4") and _has(b, "d6", "e5", "c4|c5")

def lopez_formation(w, b):
    # Blancas c3 d4 e4; negras d6 e5 y el peón c en c5, c6 o c7.
    return _has(w, "c3", "d4", "e4") and _has(b, "d6", "e5", "c5|c6|c7")

# Número de estructura (1…28) → regla en la orientación del libro.
REFINED = {27: closed_ruy_lopez, 28: lopez_formation}

def apply(w, b, mask):
    """Recalcula en `mask` los bits de las estructuras afinadas (libro e invertida)."""
    for num, rule in REFINED.items():
        bit = (num - 1) * 2
        mask &= ~(3 << bit)
        if rule(w, b):
            mask |= 1 << bit
        if rule(_flip(b), _flip(w)):
            mask |= 1 << (bit + 1)
    return mask

if __name__ == "__main__":
    src, dst = sys.argv[1], sys.argv[2]
    data = bytearray(open(src, "rb").read())
    assert data[:4] == b"PSR1"
    n = struct.unpack_from("<I", data, 4)[0]
    changed = 0
    for i in range(n):
        off = 8 + 24 * i
        w, b, m = struct.unpack_from("<QQQ", data, off)
        new = apply(w, b, m)
        if new != m:
            changed += 1
            struct.pack_into("<Q", data, off + 16, new)
    open(dst, "wb").write(data)
    print(f"claves {n}; cambiadas {changed}")
