const translations = {
  zh: "好工具会贴近正在进行的工作，缩短问题与答案之间的距离；工作继续时，它便安静退场。",
  ja: "良い道具は仕事のそばにあり、問いと答えの距離を縮めます。そして仕事が続けば、静かに姿を消します。",
  fr: "Un bon outil reste au plus près du travail, raccourcit la distance entre la question et la réponse, puis s'efface quand le travail reprend.",
};

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
      output.classList.remove("is-changing");
    }, 130);
  });
}

document.querySelector("#year").textContent = String(new Date().getFullYear());
