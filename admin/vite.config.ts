/// <reference types="vitest/config" />
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// Caddy serves the build at /admin/; the API is same-origin (/v1, /ws).
export default defineConfig({
  base: '/admin/',
  plugins: [react()],
  build: {
    outDir: 'dist',
    emptyOutDir: true,
    sourcemap: false,
    rollupOptions: {
      output: { manualChunks: { react: ['react', 'react-dom', 'react-router-dom'], map: ['leaflet', 'react-leaflet'], socket: ['socket.io-client'] } },
    },
  },
  server: {
    port: 5173,
    proxy: {
      '/v1': { target: 'http://localhost:8080', changeOrigin: true },
      '/ws': { target: 'http://localhost:8080', changeOrigin: true, ws: true },
    },
  },
  test: {
    environment: 'jsdom',
    setupFiles: ['./test/setup.ts'],
    include: ['test/**/*.test.{ts,tsx}'],
    css: false,
    globals: true,
    restoreMocks: true,
    unstubGlobals: true,
  },
});
