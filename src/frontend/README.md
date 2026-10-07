# Frontend — Portal Liliana & Seródio

## Requisitos

- Node.js 20+ e npm

## Arranque

```powershell
cd src/frontend
npm install
npm run dev
```

Abre http://localhost:5173 — o Vite faz proxy de `/api` para a API em `:5080`.

## Auth

- Cookie HTTP-only (`credentials: 'include'`)
- Sem JWT / tokens na UI
- Login PT-PT; menus: Painel · Encomendas · Rastreio · Administração
