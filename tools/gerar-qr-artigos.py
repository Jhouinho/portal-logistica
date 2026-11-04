#!/usr/bin/env python3
"""
Gera QR Codes PNG para artigos do Portal Mobile.

Conteúdo do QR = só a referência (igual ao scanner do cliente).
Ver: docs/portal-mobile-requisitos-funcionais.md §3

Uso:
  1) No SSMS (BD PHC), exportar CSV:

       SELECT LTRIM(RTRIM(ref)) AS ref,
              LTRIM(RTRIM(ISNULL(design, ''))) AS design
       FROM dbo.st WITH (NOLOCK)
       WHERE ISNULL(inactivo, 0) = 0
         AND LTRIM(RTRIM(ref)) <> ''
       ORDER BY ref;

  2) python tools/gerar-qr-artigos.py --csv artigos.csv --out qr-artigos

Dependências: pip install "qrcode[pil]"
"""
from __future__ import annotations

import argparse
import csv
import re
import sys
from pathlib import Path

try:
    import qrcode
except ImportError:
    print('Instale: pip install "qrcode[pil]"', file=sys.stderr)
    sys.exit(1)


def safe_filename(ref: str) -> str:
    s = re.sub(r'[<>:"/\\|?*\x00-\x1f]', "_", ref.strip())
    return s or "_vazio"


def load_refs(csv_path: Path) -> list[tuple[str, str]]:
    rows: list[tuple[str, str]] = []
    with csv_path.open(encoding="utf-8-sig", newline="") as f:
        sample = f.read(4096)
        f.seek(0)
        try:
            dialect = csv.Sniffer().sniff(sample, delimiters=",;\t")
        except csv.Error:
            dialect = csv.excel
        reader = csv.DictReader(f, dialect=dialect)
        if not reader.fieldnames:
            raise SystemExit("CSV sem cabeçalho.")
        fields = {h.strip().lower(): h for h in reader.fieldnames if h}
        ref_key = fields.get("ref") or fields.get("referencia") or fields.get("st.ref")
        if not ref_key:
            # 1.ª coluna
            ref_key = reader.fieldnames[0]
        design_key = fields.get("design") or fields.get("designacao") or fields.get("descrição") or fields.get("descricao")
        for row in reader:
            ref = (row.get(ref_key) or "").strip()
            if not ref:
                continue
            design = (row.get(design_key) or "").strip() if design_key else ""
            rows.append((ref, design))
    return rows


def main() -> None:
    ap = argparse.ArgumentParser(description="Gera QR PNG por referência de artigo.")
    ap.add_argument("--csv", required=True, type=Path, help="CSV com coluna ref (e opcional design)")
    ap.add_argument("--out", type=Path, default=Path("qr-artigos"), help="Pasta de saída")
    ap.add_argument("--box-size", type=int, default=8, help="Tamanho do módulo QR")
    ap.add_argument("--border", type=int, default=2, help="Margem (módulos)")
    ap.add_argument("--index-html", action="store_true", help="Gera index.html com grelha de QRs")
    args = ap.parse_args()

    if not args.csv.is_file():
        raise SystemExit(f"CSV não encontrado: {args.csv}")

    refs = load_refs(args.csv)
    if not refs:
        raise SystemExit("Nenhuma referência no CSV.")

    args.out.mkdir(parents=True, exist_ok=True)
    seen: set[str] = set()
    written = 0
    for ref, design in refs:
        if ref in seen:
            continue
        seen.add(ref)
        img = qrcode.make(
            ref,
            box_size=args.box_size,
            border=args.border,
        )
        out_file = args.out / f"{safe_filename(ref)}.png"
        img.save(out_file)
        written += 1

    print(f"OK: {written} QR(s) em {args.out.resolve()}")

    if args.index_html:
        cards: list[str] = []
        done: set[str] = set()
        for ref, design in refs:
            if ref in done:
                continue
            done.add(ref)
            fn = f"{safe_filename(ref)}.png"
            design_esc = design.replace("&", "&amp;").replace("<", "&lt;")
            ref_esc = ref.replace("&", "&amp;").replace("<", "&lt;")
            cards.append(
                f'<div class="c"><img src="{fn}" alt="{ref_esc}"/>'
                f"<div><code>{ref_esc}</code></div>"
                f'<div style="font-size:12px;color:#555">{design_esc}</div></div>'
            )
        html = (
            "<!DOCTYPE html><html lang=pt><head><meta charset=utf-8>"
            "<title>QR Artigos</title>"
            "<style>body{font-family:system-ui;padding:16px}.g{display:grid;"
            "grid-template-columns:repeat(auto-fill,minmax(180px,1fr));gap:16px}"
            ".c{border:1px solid #ccc;border-radius:8px;padding:12px;text-align:center}"
            "img{width:100%;max-width:160px;image-rendering:pixelated}</style></head><body>"
            "<h1>QR Artigos</h1><p>Conteúdo do QR = referência (ler no Portal Mobile)</p>"
            f'<div class="g">{"".join(cards)}</div></body></html>'
        )
        index = args.out / "index.html"
        index.write_text(html, encoding="utf-8")
        print(f"Index: {index.resolve()}")


if __name__ == "__main__":
    main()
