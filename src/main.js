import { Elm } from "./Main.elm";

const KEY = "rr-state";

const app = Elm.Main.init({
  node: document.getElementById("app"),
  flags: null  // Scenario loaded via HTTP, not flags
});

// Save state to localStorage
app.ports.saveToStorage.subscribe(s => localStorage.setItem(KEY, s));

// Clear saved state and reload
app.ports.clearStorage.subscribe(() => {
  localStorage.removeItem(KEY);
  location.reload();
});
