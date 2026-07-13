"use client";

import { useEffect, useState } from "react";

/**
 * Light (paper) is the default for everyone; dark is a per-visitor
 * opt-in stamped as data-theme="dark" on <html> and persisted in
 * localStorage. A pre-paint script in layout.tsx re-applies it on load
 * so a dark-mode visitor never sees a paper flash.
 */
export default function ThemeToggle() {
  const [dark, setDark] = useState(false);

  // The server always renders light; sync with whatever the pre-paint
  // script applied once we're on the client.
  useEffect(() => {
    setDark(document.documentElement.dataset.theme === "dark");
  }, []);

  function toggle() {
    const next = !dark;
    setDark(next);
    if (next) {
      document.documentElement.dataset.theme = "dark";
    } else {
      delete document.documentElement.dataset.theme;
    }
    try {
      localStorage.setItem("vani-theme", next ? "dark" : "light");
    } catch {
      // Private browsing without storage — the toggle still works for
      // this visit, it just won't persist.
    }
  }

  return (
    <button
      type="button"
      onClick={toggle}
      aria-label={dark ? "Switch to light theme" : "Switch to dark theme"}
      aria-pressed={dark}
      className="inline-flex h-[34px] w-[34px] cursor-pointer items-center justify-center rounded-full border-[1.5px] border-canvas-ink bg-transparent text-[15px] leading-none text-canvas-ink transition-colors hover:bg-canvas-ink hover:text-canvas"
    >
      <span aria-hidden="true">{dark ? "☀" : "☾"}</span>
    </button>
  );
}
