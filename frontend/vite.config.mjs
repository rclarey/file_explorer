import gleam from "vite-gleam";

export default {
  plugins: [gleam()],
  server: {
    proxy: {
      "/api": "http://localhost:8000",
      "/download": "http://localhost:8000"
    }
  }
};