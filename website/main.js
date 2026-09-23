const translations = {
  zh: "好工具会贴近正在进行的工作，缩短问题与答案之间的距离；工作继续时，它便安静退场。",
  ja: "良い道具は仕事のそばにあり、問いと答えの距離を縮めます。そして仕事が続けば、静かに姿を消します。",
  fr: "Un bon outil reste au plus près du travail, raccourcit la distance entre la question et la réponse, puis s'efface quand le travail reprend.",
};

const LANGUAGE_PREFERENCE_KEY = "linguadock.site.language";

// Remember which language page the visitor picked, so the auto-redirect below
// never overrides a deliberate choice.
for (const link of document.querySelectorAll(".lang-switch a")) {
  link.addEventListener("click", () => {
    try {
      localStorage.setItem(LANGUAGE_PREFERENCE_KEY, link.hreflang);
    } catch {
      // Private browsing or a blocked store: falling through just means the
      // visitor gets asked again next time, which is harmless.
    }
  });
}

// First visit to the English root from a Chinese browser: send them to the
// matching Chinese page once. Only from "/" — redirecting from a language page
// would fight the switcher.
if (location.pathname === "/" || location.pathname === "/index.html") {
  let stored = null;
  try {
    stored = localStorage.getItem(LANGUAGE_PREFERENCE_KEY);
  } catch {
    stored = null;
  }

  if (!stored) {
    const preferred = (navigator.languages ?? [navigator.language ?? ""]).find(
      (tag) => tag.toLowerCase().startsWith("zh"),
    );

    if (preferred) {
      const lower = preferred.toLowerCase();
      // Hant is signalled either by the script subtag or by a region that uses
      // Traditional Chinese. Everything else Chinese goes to Simplified.
      const isTraditional =
        lower.includes("hant") ||
        lower.includes("-tw") ||
        lower.includes("-hk") ||
        lower.includes("-mo");
      location.replace(isTraditional ? "/zh-Hant/" : "/zh-Hans/");
    }
  }
}

const output = document.querySelector("#demo-output");
const languageButtons = document.querySelectorAll("[data-language]");

for (const button of languageButtons) {
  button.addEventListener("click", () => {
    const language = button.dataset.language;
    if (!language || !translations[language]) return;

    for (const otherButton of languageButtons) {
      otherButton.setAttribute(
        "aria-pressed",
        String(otherButton === button),
      );
    }

    output.classList.add("is-changing");
    window.setTimeout(() => {
      output.textContent = translations[language];
      output.lang = language === "zh" ? "zh-Hans" : language;
      output.classList.remove("is-changing");
    }, 130);
  });
}

document.querySelector("#year").textContent = String(new Date().getFullYear());
