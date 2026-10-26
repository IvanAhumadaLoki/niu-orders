import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

// Configuración de Vite para el dashboard.
export default defineConfig({
  plugins: [react()],
  server: {
    // Escucha en todas las interfaces: el servidor corre dentro de un
    // contenedor de Docker y el navegador entra desde fuera.
    host: true,
    // Puerto fijo: debe coincidir con el origen autorizado por CORS en la API
    // (CORS_ORIGINS, por defecto http://localhost:5173). `strictPort` hace que
    // falle en vez de elegir otro puerto en silencio, que la API rechazaría.
    port: 5173,
    strictPort: true,
    // Detecta cambios consultando los archivos cada cierto tiempo, en vez de
    // esperar avisos del sistema operativo. Solo hace falta si el recargado
    // automático no funciona con tu configuración de Docker:
    //   VITE_USE_POLLING=true docker compose up -d web
    watch: { usePolling: process.env.VITE_USE_POLLING === "true" },
  },
});