import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import App from "./App.jsx";
import "./styles.css";

// Punto de entrada: monta la aplicación dentro del <div id="root"> de index.html.
createRoot(document.getElementById("root")).render(
  <StrictMode>
    <App />
  </StrictMode>,
);