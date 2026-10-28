# HTTPS no Portal (produção) — passo a passo

| | |
| --- | --- |
| Objectivo | Câmara QR no telemóvel (`isSecureContext` / HTTPS) |
| Site IIS | `<IIS_SITE>` · pasta `<IIS_APP_PATH>` · binding HTTP actual no inventário IT |
| Host | `<IIS_HOST>` (SO / edição no inventário) |
| Âmbito | **Só rede interna** (LAN / Wi‑Fi empresa) — sem Internet pública, salvo decisão IT explícita |
| Deploy PM | Actividade **distinta** — ver [`prod-passo-a-passo-aplicar-pedidos-mobile.md`](./prod-passo-a-passo-aplicar-pedidos-mobile.md) |

> Hosts, IPs e nomes DNS reais: **inventário IT**, fora do Git.
>
> Não incluir passwords, tokens, chaves privadas nem connection strings neste documento.
>
> Rótulos: **Leitura / orientação** · **[Admin — altera IIS/rede]**.

Sem HTTPS válido, o browser no smartphone **bloqueia** a câmara. Desktop em HTTP pode “parecer” ok; o telemóvel não.

### Só rede interna — sem instalar certificados nos telemóveis (**Leitura / orientação**)

Os browsers dos telemóveis **já confiam** em CAs públicas (Let's Encrypt, DigiCert, etc.).

**Não confiam** automaticamente na CA da empresa → por isso a CA interna obriga a instalar a raiz em cada telemóvel.

Para **não** instalar nada nos telemóveis:

1. Usar um **nome de domínio real** (exemplo ilustrativo: `portal.exemplo.empresa`), não `.local`
2. Certificado de **CA pública** (recomendado: **Let's Encrypt**)
3. Tráfego **só na LAN**: DNS **interno** desse nome → IP privado de `<IIS_HOST>` (split DNS). O servidor **não** precisa de estar aberto na Internet
4. Binding HTTPS no IIS + abrir `https://…` no Wi‑Fi da empresa

Emissão Let's Encrypt sem expor o IIS: desafio **DNS-01** (registo TXT no DNS do domínio). O portal continua inacessível de fora se o firewall não publicar 443 para a Internet.

---

## Escolher o tipo de certificado (**Leitura / orientação**)

| Opção | Quando usar | Instalar cert no telemóvel? |
| --- | --- | --- |
| **A — Domínio real + Let's Encrypt (DNS-01) + DNS interno** | Uso normal na LAN **sem** tocar nos telemóveis | **Não** |
| **A2 — CA da empresa** | Só se aceitares instalar a CA raiz nos telemóveis | **Sim** (evitar) |
| **B — Autoassinado** | Evitar | Sim / bloqueia |
| **C — Túnel Cloudflare** | Teste rápido de QR | Não (URL temporária) |

**Recomendação (só rede interna, sem instalar nada no telemóvel):** opção **A**.

**Teste rápido de QR:** opção **C** — **requer autorização IT**; **não** é arquitetura de go-live permanente.

---

## Opção A — HTTPS na LAN sem instalar nada nos telemóveis (recomendado)

### A1. Domínio real (**Leitura / orientação**)

Precisas de um nome sob um domínio que a empresa **já tenha** (ou registe). Exemplos **ilustrativos** (não são valores de produção):

- `https://portal.exemplo.empresa`
- `https://portal.empresa.com`

**Não** uses `*.local` nem só o hostname NetBIOS do servidor: CAs públicas **não** emitem para isso, e sem CA pública o telemóvel exige instalar certificado.

O nome no certificado = o que se escreve no browser do telemóvel. Nome real: inventário IT / DNS.

### A2. DNS interno — **[Admin — altera IIS/rede]** (ou equipa DNS)

No DNS **da rede interna**:

- Registo **A**: `<PUBLIC_HOSTNAME>` → IP privado de `<IIS_HOST>`

Assim, no Wi‑Fi da empresa, `https://<PUBLIC_HOSTNAME>` vai para o servidor interno.

**Não** abras a porta 443 de `<IIS_HOST>` para a Internet salvo decisão IT explícita.

### A3. Obter certificado Let's Encrypt (DNS-01) — **[Admin — altera IIS/rede]** / DNS

Sem abrir o site à Internet:

1. No PC/servidor com ferramenta ACME (ex. **win-acme**, Certify The Web, ou script acordado com IT).
2. Pedir certificado para `<PUBLIC_HOSTNAME>` com validação **DNS-01**.
3. A ferramenta pede um registo **TXT** `_acme-challenge.…` no DNS onde o domínio está alojado.
4. Criar esse TXT → a CA valida → recebes o certificado (ficheiros ou PFX).
5. Renovação: repetir DNS-01 a cada ~60–90 dias (automatizar se possível).

Certificado comercial (DigiCert, etc.) para o mesmo nome também serve — o telemóvel já confia; o processo IIS é igual.

### A4. Instalar o certificado no Windows — **[Admin — altera IIS/rede]**

1. Copia o `.pfx` para o servidor (path temporário acordado com IT).
2. Duplo clique → *Local Machine* → colocar em **Personal**.
3. Ou PowerShell (Admin). A password do PFX é pedida **interactivamente** — não a escrevas neste documento:

```powershell
$password = Read-Host -AsSecureString -Prompt 'Password do PFX'
Import-PfxCertificate -FilePath '<PFX_PATH>' -CertStoreLocation Cert:\LocalMachine\My -Password $password
```

4. Anota o **thumbprint** (inventário interno):

```powershell
Get-ChildItem Cert:\LocalMachine\My | Where-Object { $_.Subject -match '<PUBLIC_HOSTNAME_FRAGMENT>' } |
  Select-Object Subject, Thumbprint, NotAfter
```

### A5. Binding HTTPS no site — **[Admin — altera IIS/rede]**

PowerShell (Admin) — exemplo porta **443** (ajusta thumbprint e hostname do inventário):

```powershell
Import-Module WebAdministration

$site = '<IIS_SITE>'
$thumb = '<CERT_THUMBPRINT_NO_SPACES>'
$hostHeader = '<PUBLIC_HOSTNAME>'   # '' só se política IT permitir binding sem host header

# Remover binding https antigo deste site, se existir
Get-WebBinding -Name $site -Protocol https -ErrorAction SilentlyContinue |
  ForEach-Object { Remove-WebBinding -Name $site -Protocol $_.protocol -BindingInformation $_.bindingInformation }

# Criar binding
New-WebBinding -Name $site -Protocol https -Port 443 -IPAddress '*' -HostHeader $hostHeader

# Associar certificado (IIS 8+)
$guid = [guid]::NewGuid().ToString('B')
netsh http delete sslcert ipport=0.0.0.0:443 2>$null
netsh http add sslcert ipport=0.0.0.0:443 certhash=$thumb appid=$guid certstorename=MY
```

Alternativa gráfica: IIS Manager → site → Bindings → Add → `https` → porta `443` → escolher o certificado.

Podes **manter** o binding HTTP existente durante a transição.

### A6. Firewall — **[Admin — altera IIS/rede]**

Abrir entrada TCP **443** (ou a porta HTTPS escolhida) no Windows Firewall / firewall de rede, para os telemóveis na LAN — conforme política IT.

### A7. Config da app (se mudares o URL) — **[Admin — altera IIS/rede]**

Em `<IIS_APP_PATH>\appsettings.Production.json` (editar com cuidado, backup antes):

- `AllowedHosts` — incluir o novo hostname
- Se existirem `Cors:Origins` / URLs absolutas — alinhar com `https://…`
- **Não** apagar connection strings / outros segredos


Depois:

```powershell
Restart-WebAppPool -Name <IIS_APP_POOL>
```

### A8. Testar (**Leitura / validação**)

1. No PC: `https://<PUBLIC_HOSTNAME>/` (cadeado / sem aviso grave).
2. No telemóvel (Wi‑Fi empresa): o mesmo URL.
3. Login → Ler QR → autorizar câmara → deve pedir permissão (não erro de HTTPS).

Se o telemóvel mostrar aviso de certificado e não deixa avançar → o certificado **não é de confiança** nesse aparelho (volta a A3: CA correcta ou instalar CA raiz nos telemóveis — último recurso).

---

## Opção C — Túnel HTTPS para testar QR (rápido)

**Requer autorização IT.** Expõe temporariamente um URL público; **não** substitui HTTPS permanente (A).

No host que alcance o portal (origem tipicamente HTTP local do inventário UAT/prod autorizado):

1. Instalar `cloudflared` (ou equivalente).
2. Adaptar `tools/start-uat-https-tunnel.ps1` apontando a origem acordada — **só se** IT autorizar.
3. Abrir no telemóvel o URL `https://….trycloudflare.com` gerado.
4. Em `AllowedHosts` do Production.json pode ser preciso `*.trycloudflare.com` (como no UAT) — alteração de config = **[Admin]**.

---

## Checklist mínimo “QR no telemóvel OK”

| # | Item | ☐ |
| --- | --- | --- |
| 1 | Nome DNS definido e a resolver no telemóvel | |
| 2 | Certificado válido para esse nome, confiado pelo telemóvel | |
| 3 | Binding HTTPS no site IIS | |
| 4 | Porta HTTPS aberta na firewall (LAN) | |
| 5 | App Pool reciclado após config | |
| 6 | Abrir **https://…** (não só http) no telemóvel | |
| 7 | Câmara autorizada e QR lê | |

---

## Relação com o deploy dos pedidos mobile

| Trabalho | Depende de HTTPS? |
| --- | --- |
| SQL 098–100 + publish do release PM autorizado | Não |
| QR com câmara no smartphone | **Sim** |
| Flag pedidos internos | Não (é config à parte) |
| Grants Kapps `097` (condicional) | Não |

Podes fazer HTTPS **antes**, **depois** ou **em paralelo** ao publish PM; para a empresa usar scanner QR no telemóvel, HTTPS tem de estar feito.
