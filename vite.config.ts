import tailwindcss from "@tailwindcss/vite"
import react from "@vitejs/plugin-react"
import { defineConfig } from "vite"

export default defineConfig(({ command }) => ({
  // Relative asset paths so a later Capacitor wrap can load the built files.
  base: command === "build" ? "./" : "/",
  plugins: [react(), tailwindcss()],
  server: {
    host: "0.0.0.0",
    port: 47331,
    strictPort: true,
  },
  preview: {
    host: "0.0.0.0",
    port: 47331,
    strictPort: true,
  },
}))
