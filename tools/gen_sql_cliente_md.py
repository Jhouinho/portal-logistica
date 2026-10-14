# -*- coding: utf-8 -*-
"""Gera docs/SQL_APLICAR_CLIENTE.md + sql/DEPLOY_CLIENTE_COMPLETO.sql"""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SQL_DIR = ROOT / "sql"
OUT_MD = ROOT / "docs" / "SQL_APLICAR_CLIENTE.md"
OUT_SQL = SQL_DIR / "DEPLOY_CLIENTE_COMPLETO.sql"

SKIP_RE = re.compile(r"validate|discover|_tmp|090_seed|073_fix", re.I)


def sort_key(p: Path):
    m = re.match(r"^(\d+)", p.name)
    return (int(m.group(1)) if m else 9999, p.name)


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
        )
    ):
        return "Campo / migração"
    return "SP / alter SP"


def main() -> None:
    files = sorted(
        [
            p
            for p in SQL_DIR.glob("*.sql")
            if p.name != OUT_SQL.name and not SKIP_RE.search(p.name)
        ],
        key=sort_key,
    )

    md: list[str] = []
    md.append("# SQL a aplicar na BD do cliente — views, SPs e objectos Portal")
    md.append("")
    md.append("| | |")
    md.append("| --- | --- |")
    md.append("| Projecto | Liliana & Seródio — Portal de Logística |")
    md.append("| Pré-requisito | Campos de utilizador já criados (Framework + Actualizar Tabela) |")
    md.append("| Actualizado | 2026-10-14 |")
    md.append(f"| Scripts | {len(files)} (sem validate / seed teste / tmp) |")
    md.append("")
    md.append("## Como usar")
    md.append("")
    md.append("1. **Backup** da BD PHC do cliente.")
    md.append("2. Abrir SSMS ligado à BD correcta.")
    md.append(
        "3. **Recomendado:** executar de uma vez "
        "[`sql/DEPLOY_CLIENTE_COMPLETO.sql`](../sql/DEPLOY_CLIENTE_COMPLETO.sql)."
    )
    md.append("4. Alternativa: copiar cada bloco abaixo **por ordem** (secção Scripts).")
    md.append(
        "5. Nos scripts de **grant**, confirmar o login SQL "
        "(default `portal_app`) — alterar o nome se for diferente."
    )
    md.append("6. **Não** executar `090_seed_clone_encomendas_teste.sql`.")
    md.append(
        "7. Depois: criar utilizador Identity "
        "(`tools/criar-utilizador-portal`) e `US.u_usaPort = 1`."
    )
    md.append("")
    md.append("## Ordem dos scripts")
    md.append("")
    md.append("| # | Ficheiro | Tipo |")
    md.append("| --- | --- | --- |")
    for i, p in enumerate(files, 1):
        md.append(f"| {i} | `{p.name}` | {kind_of(p.name)} |")

    md.append("")
    md.append("---")
    md.append("")
    md.append("## Scripts (código para copiar)")
    md.append("")

    sql_parts: list[str] = []
    sql_parts.append("/* ============================================================")
    sql_parts.append("   DEPLOY CLIENTE — Portal Liliana & Seródio")
    sql_parts.append("   Gerado por tools/gen_sql_cliente_md.py")
    sql_parts.append("   Pré-requisito: campos U_* no Framework.")
    sql_parts.append("   NÃO inclui 090 seed de testes.")
    sql_parts.append("   ============================================================ */")
    sql_parts.append("SET NOCOUNT ON;")
    sql_parts.append("GO")
    sql_parts.append("")

    for i, p in enumerate(files, 1):
        text = p.read_text(encoding="utf-8", errors="replace")
        text = text.replace("\r\n", "\n").replace("\r", "\n").rstrip() + "\n"
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

        sql_parts.append("")
        sql_parts.append(f"/* ========== {i:02d} / {p.name} ========== */")
        sql_parts.append(text.rstrip())
        sql_parts.append("GO")
        sql_parts.append("")

    OUT_MD.write_text("\n".join(md), encoding="utf-8")
    OUT_SQL.write_text("\n".join(sql_parts), encoding="utf-8")
    print(f"MD  {OUT_MD} ({OUT_MD.stat().st_size} bytes)")
    print(f"SQL {OUT_SQL} ({OUT_SQL.stat().st_size} bytes)")
    print(f"scripts: {len(files)}")


if __name__ == "__main__":
    main()
