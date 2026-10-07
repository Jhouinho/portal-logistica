# gerar-hash-portalph

Gera (e opcionalmente verifica) hashes **ASP.NET `PasswordHasher`** para o campo PHC `US.u_portalph`.

## Requisitos

- .NET 8 SDK

## Gerar hash

Na raiz do projeto `Liliana&Serodio`:

```powershell
dotnet run --project tools/gerar-hash-portalph -- --password "TrocarJa_123!" --usercode ANA
```

O programa imprime:

1. O hash a colar em `u_portalph`
2. Um `UPDATE` SQL de exemplo (UAT)

## Verificar hash

```powershell
dotnet run --project tools/gerar-hash-portalph -- --verify "AQAAAA..." --password "TrocarJa_123!"
```

## Regras

- **Nunca** gravar a password em texto na BD
- Só em **UAT** até ao GO formal de Produção
- Utilizador ativo: `ISNULL(inactivo, 0) = 0`
- Depois: `SELECT` em `view_HCA_utilizadores` / `EXEC sp_HCA_validar_login`

Ver também: [`sql/001_user_fields.md`](../../sql/001_user_fields.md) · [`docs/fase-0b-sp-HCA-validar-login.md`](../../docs/fase-0b-sp-HCA-validar-login.md)
