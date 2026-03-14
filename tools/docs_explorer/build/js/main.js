import { startApp } from "./app.js";
startApp().catch((err) => {
    const viewerEl = document.getElementById("viewer");
    if (!viewerEl)
        return;
    viewerEl.innerHTML = `
    <div class="callout">
      Failed to initialize docs explorer.
    </div>
    <pre><code>${String(err).replaceAll("&", "&amp;").replaceAll("<", "&lt;").replaceAll(">", "&gt;")}</code></pre>
  `;
});
