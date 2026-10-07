import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import { VitePWA } from 'vite-plugin-pwa'

export default defineConfig({
  plugins: [
    react(),
    VitePWA({
      registerType: 'autoUpdate',
      injectRegister: 'auto',
      strategies: 'generateSW',
      includeAssets: ['favicon.png', 'favicon-32.png', 'apple-touch-icon.png', 'pwa-192.png', 'pwa-512.png'],
      devOptions: {
        enabled: true,
      },
      manifest: {
        name: 'Portal Logística — Liliana & Seródio',
        short_name: 'Portal Logística',
        start_url: '/',
        display: 'standalone',
        theme_color: '#3DB2FF',
        background_color: '#0B1220',
        icons: [
          {
            src: 'pwa-192.png',
            sizes: '192x192',
            type: 'image/png',
          },
          {
            src: 'pwa-512.png',
            sizes: '512x512',
            type: 'image/png',
          },
        ],
      },
    }),
  ],
  server: {
    port: 5173,
    proxy: {
      '/api': {
        target: 'http://localhost:5080',
        changeOrigin: true,
      },
      '/hubs': {
        target: 'http://localhost:5080',
        changeOrigin: true,
        ws: true,
      },
      '/health': {
        target: 'http://localhost:5080',
        changeOrigin: true,
      },
    },
  },
})
