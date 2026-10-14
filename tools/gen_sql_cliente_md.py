# -*- coding: utf-8 -*-
"""Gera docs/SQL_APLICAR_CLIENTE.md + packs SQL para o cliente."""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SQL_DIR = ROOT / "sql"
OUT_MD = ROOT / "docs" / "SQL_APLICAR_CLIENTE.md"
OUT_SQL = SQL_DIR / "DEPLOY_CLIENTE_COMPLETO.sql"
OUT_SQL_BI2 = SQL_DIR / "DEPLOY_CLIENTE_BI2_BO3.sql"

SKIP_RE = re.compile(
    r"validate|discover|_tmp|090_seed|073_test|DEPLOY_CLIENTE|^_grant",
    re.I,
)

# Scripts legados que assumem campos em BI/BO (u_upickrdr, etc.) — NÃO correr
# numa BD nova onde os campos já estão em BI2/BO3.
LEGACY_PRE_041 = {
    "012_create_view_HCA_encomendas_abertas.sql",
    "014_create_view_HCA_encomenda_linhas.sql",
    "016_create_view_HCA_rastreio_artigos.sql",
    "018_create_view_HCA_artigo_encomendas.sql",
    "022_create_sp_HCA_atualizar_linha_qtt_preco.sql",
    "024_create_sp_HCA_atualizar_qtd_autorizada.sql",
    "026_create_sp_HCA_alocacao_proporcional.sql",
    "034_alter_view_HCA_encomenda_linhas_unidade.sql",
    "035_alter_sp_HCA_alocacao_proporcional_disponivel_cor.sql",
    "036_alter_sp_HCA_atualizar_qtd_autorizada_permitir_stock.sql",
    "037_alter_view_HCA_encomendas_abertas_picking.sql",
    "037b_add_bo_u_upickrdt_if_missing.sql",
    "038_create_sp_HCA_marcar_pronta_picking.sql",
    "039_alter_views_excluir_pronta_picking.sql",
    "040_alter_sp_HCA_marcar_pronta_picking_linhas_zero.sql",
}


def sort_key(p: Path):
    m = re.match(r"^(\d+)", p.name)
    return (int(m.group(1)) if m else 9999, p.name)


def strip_bom(text: str) -> str:
    if text.startswith("\ufeff"):
        return text[1:]
    return text


def read_sql(p: Path) -> str:
    raw = p.read_bytes()
    if raw[:3] == b"\xef\xbb\xbf":
        raw = raw[3:]
    text = raw.decode("utf-8", errors="replace")
    return strip_bom(text).replace("\r\n", "\n").replace("\r", "\n").rstrip() + "\n"


def brief(text: str) -> str:
    lines: list[str] = []
    for line in text.splitlines()[:50]:
        s = line.strip()
        if s.startswith("--") and len(s) > 3:
            t = s.lstrip("- ").strip()
            if not t or t.startswith("===="):
                continue
            if t.lower().startswith("script:"):
                continue
            lines.append(t)
        if len(lines) >= 5:
            break
    return " ".join(lines)[:500] if lines else "Objecto SQL do Portal."


def kind_of(name: str) -> str:
    n = name.lower()
    if name.startswith("000_"):
        return "Pré-requisito"
    if "grant" in n:
        return "Grant"
    if "view" in n:
        return "Vista"
    if "create_u_hca" in n or "alter_u_hca" in n or "identity" in n:
        return "Tabela Portal"
    if "seed_role" in n:
        return "Seed role"
    if any(
        x in n
        for x in (
            "add_us",
            "add_bo",
            "migrate",
            "backfill",
            "u_qttorig",
            "cor_efectiva",
            "verificar",
            "criar_login",
        )
    ):
        return "Campo / migração / setup"
    return "SP / alter SP"


def script_num(name: str) -> int:
    m = re.match(r"^(\d+)", name)
    return int(m.group(1)) if m else 9999


def main() -> None:
    files = sorted(
        [p for p in SQL_DIR.glob("*.sql") if not SKIP_RE.search(p.name)],
        key=sort_key,
    )

    # Pack BI2/BO3: setup (000, 010, 020, 028-033) + 041 em diante; sem legado pré-041
    # 000_criar_login fica FORA do pack (USE master + password) — correr à mão.
    # GRANTs vão para o fim (objectos 041+ têm de existir primeiro).
    bi2_core = [
        p
        for p in files
        if p.name not in LEGACY_PRE_041
        and p.name != "000_criar_login_portal_app.sql"
        and "grant" not in p.name.lower()
        and (
            p.name.startswith("000_")
            or script_num(p.name) in {10, 20, 28, 29, 31, 32, 33}
            or script_num(p.name) >= 41
        )
    ]
    bi2_grants = [
        p
        for p in files
        if "grant" in p.name.lower() and p.name not in LEGACY_PRE_041
    ]
    bi2_files = bi2_core + bi2_grants

    write_md(files, bi2_files)
    write_sql(OUT_SQL, files, title="COMPLETO (historico - inclui legado BI/BO)")
    write_sql(
        OUT_SQL_BI2,
        bi2_files,
        title="BI2/BO3 - usar no cliente quando campos ja estao nas extensoes",
    )
    print(f"MD  {OUT_MD} ({OUT_MD.stat().st_size} bytes)")
    print(f"SQL {OUT_SQL} ({OUT_SQL.stat().st_size} bytes) n={len(files)}")
    print(f"SQL {OUT_SQL_BI2} ({OUT_SQL_BI2.stat().st_size} bytes) n={len(bi2_files)}")


def write_sql(path: Path, files: list[Path], title: str) -> None:
    parts: list[str] = []
    parts.append("/* ============================================================")
    parts.append(f"   DEPLOY CLIENTE -- {title}")
    parts.append("   Gerado por tools/gen_sql_cliente_md.py")
    parts.append("   Pre-requisito: campos U_* em BI2/BO3/BO2/US/STOBS.")
    parts.append("   1) Correr 000_criar_login_portal_app.sql (ajustar BD/password)")
    parts.append("   2) Correr este ficheiro")
    parts.append("   NAO inclui 090 seed de testes.")
    if "COMPLETO" in title.upper() or "historico" in title.lower():
        parts.append("   AVISO: pack historico inclui scripts pre-041 (BI/BO).")
        parts.append("   Em cliente com campos em BI2/BO3 usar DEPLOY_CLIENTE_BI2_BO3.sql")
    parts.append("   ============================================================ */")
    parts.append("SET NOCOUNT ON;")
    parts.append("GO")
    parts.append("")

    for i, p in enumerate(files, 1):
        text = read_sql(p)
        parts.append("")
        parts.append(f"/* ========== {i:02d} / {p.name} ========== */")
        parts.append(text.rstrip())
        parts.append("GO")
        parts.append("")

    path.write_text("\n".join(parts), encoding="utf-8")


def write_md(all_files: list[Path], bi2_files: list[Path]) -> None:
    md: list[str] = []
    md.append("# SQL a aplicar na BD do cliente — views, SPs e objectos Portal")
    md.append("")
    md.append("| | |")
    md.append("| --- | --- |")
    md.append("| Projecto | Liliana & Seródio — Portal de Logística |")
    md.append("| Pré-requisito | Campos de utilizador em **BI2 / BO3 / BO2** (não em BI/BO) |")
    md.append("| Actualizado | 2026-10-14 |")
    md.append("")
    md.append("## Importante (erros `Invalid column name`)")
    md.append("")
    md.append(
        "Os scripts antigos (`012`…`040`) referem `BI.u_qttorig`, `BO.u_upickrdr`, etc. "
        "No PHC CS os campos estão em **`BI2` / `BO3`** com nomes `u_pickrdr` / `u_pickrdt` "
        "(não `u_upickrdr`). Por isso o pack **completo histórico falha** numa BD nova correcta."
    )
    md.append("")
    md.append("**Usar no cliente:**")
    md.append("")
    md.append("1. [`sql/000_verificar_campos_bi2_bo3.sql`](../sql/000_verificar_campos_bi2_bo3.sql) — todos os `bytes` NOT NULL")
    md.append("2. [`sql/000_criar_login_portal_app.sql`](../sql/000_criar_login_portal_app.sql) — criar login/user (ajustar BD + password)")
    md.append(
        "3. [`sql/DEPLOY_CLIENTE_BI2_BO3.sql`](../sql/DEPLOY_CLIENTE_BI2_BO3.sql) — "
        "**este** é o pack correcto (salta legado pré-041)"
    )
    md.append("")
    md.append("Se já correste o pack completo e falhou: **não há problema** — volta a correr só o `DEPLOY_CLIENTE_BI2_BO3.sql` (é idempotente com `CREATE OR ALTER`).")
    md.append("")
    md.append("## Como usar")
    md.append("")
    md.append("1. **Backup** da BD PHC.")
    md.append("2. SSMS → BD correcta.")
    md.append("3. Criar `portal_app` (passo 2 acima).")
    md.append("4. Executar `DEPLOY_CLIENTE_BI2_BO3.sql`.")
    md.append("5. Utilizador Identity + `US.u_usaPort = 1`.")
    md.append("6. **Não** executar `090_seed_clone_encomendas_teste.sql`.")
    md.append("")
    md.append("## Ordem — pack BI2/BO3 (recomendado)")
    md.append("")
    md.append("| # | Ficheiro | Tipo |")
    md.append("| --- | --- | --- |")
    for i, p in enumerate(bi2_files, 1):
        md.append(f"| {i} | `{p.name}` | {kind_of(p.name)} |")

    md.append("")
    md.append("---")
    md.append("")
    md.append("## Scripts do pack BI2/BO3 (código)")
    md.append("")

    for i, p in enumerate(bi2_files, 1):
        text = read_sql(p)
        desc = brief(text)
        md.append(f"### {i}. `{p.name}`")
        md.append("")
        md.append(desc)
        md.append("")
        md.append("```sql")
        md.append(text.rstrip())
        md.append("```")
        md.append("")
        md.append("---")
        md.append("")

    md.append("")
    md.append("## Anexo — scripts legados ignorados neste pack")
    md.append("")
    md.append("Não usar numa BD com campos já em BI2/BO3:")
    md.append("")
    for name in sorted(LEGACY_PRE_041):
        md.append(f"- `{name}`")
    md.append("")

    OUT_MD.write_text("\n".join(md), encoding="utf-8")


if __name__ == "__main__":
    main()
