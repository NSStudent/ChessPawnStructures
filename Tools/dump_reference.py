# Vuelca un PGN a un fichero binario para comparar ChessPawnStructures con las
# reglas de referencia escritas aparte en Python (python-chess).
#
# Uso:
#   uv run --with chess python3 Tools/dump_reference.py RULES.py PARTIDAS.pgn SALIDA.bin [LIMITE]
#
# RULES.py es el fichero de reglas de referencia (define classify(w, b) con
# nombres "NN Nombre" y "NN Nombre (inv.)"). No se copia aquí: se importa.
#
# Formato (little endian):
#   "PSR1"
#   u32 nKeys; nKeys × (u64 blancas, u64 negras, u64 máscara Python)
#       bit de la máscara = (NN - 1) * 2 + (1 si «(inv.)»)
#   u32 nGames; por partida: u16 plyInicial, u16 nPlies, nPlies × u32 índice de clave
#       plyInicial = (jugada - 1) * 2 + (1 si juegan negras) de la posición inicial.
import importlib.util, struct, sys
import chess, chess.pgn

rules_path, pgn_path, out_path = sys.argv[1], sys.argv[2], sys.argv[3]
limit = int(sys.argv[4]) if len(sys.argv) > 4 else 10**9

spec = importlib.util.spec_from_file_location("rules", rules_path)
rules = importlib.util.module_from_spec(spec)
spec.loader.exec_module(rules)

def mask(names):
    m = 0
    for n in names:
        inv = n.endswith(" (inv.)")
        num = int(n.split()[0])
        m |= 1 << ((num - 1) * 2 + (1 if inv else 0))
    return m

keys = {}
key_list = []
games = []
n = 0
with open(pgn_path, encoding="utf-8", errors="replace") as f:
    while n < limit:
        g = chess.pgn.read_game(f)
        if g is None:
            break
        n += 1
        b = g.board()
        initial = (b.fullmove_number - 1) * 2 + (0 if b.turn == chess.WHITE else 1)
        seq = []
        for mv in g.mainline_moves():
            b.push(mv)
            k = (b.pawns & b.occupied_co[chess.WHITE], b.pawns & b.occupied_co[chess.BLACK])
            i = keys.get(k)
            if i is None:
                i = len(key_list)
                keys[k] = i
                key_list.append(k)
            seq.append(i)
        games.append((initial, seq))
        if n % 10000 == 0:
            print(f"… {n}", file=sys.stderr, flush=True)

with open(out_path, "wb") as out:
    out.write(b"PSR1")
    out.write(struct.pack("<I", len(key_list)))
    for w, bl in key_list:
        out.write(struct.pack("<QQQ", w, bl, mask(rules.classify(w, bl))))
    out.write(struct.pack("<I", len(games)))
    for initial, seq in games:
        out.write(struct.pack("<HH", initial, min(len(seq), 65535)))
        out.write(struct.pack(f"<{min(len(seq), 65535)}I", *seq[:65535]))
print(f"partidas {len(games)}; claves {len(key_list)}", file=sys.stderr)
