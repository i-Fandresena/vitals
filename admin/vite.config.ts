import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import tailwindcss from '@tailwindcss/vite';

export default defineConfig({
  plugins: [react(), tailwindcss()],
  build: {
    // L'espace d'administration s'utilise sur ordinateur, depuis le CSB ou le
    // district : des connexions lentes, comme pour l'application mobile.
    chunkSizeWarningLimit: 600,
  },
});
