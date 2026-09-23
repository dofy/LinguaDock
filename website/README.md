# LinguaDock Product Site

LinguaDock 的静态产品介绍站，使用 Vite 构建并通过 Cloudflare Workers Static Assets 部署。

```bash
pnpm install
pnpm dev
```

构建与本地预览：

```bash
pnpm build
pnpm preview
```

完成 Cloudflare 登录后部署：

```bash
pnpm run deploy
```

> `pnpm deploy` 是 pnpm 自己的内置命令（把工作区包部署到一个目录），会直接报
> `ERR_PNPM_INVALID_DEPLOY_TARGET`。必须写 `pnpm run deploy` 才会跑 package.json 里的脚本。

## 三语页面

每种语言一个独立静态页，而不是运行时切文案——营销页要让搜索引擎分别收录。

| 路径 | 语言 | 文件 |
|------|------|------|
| `/` | English（也是 `hreflang="x-default"`） | `index.html` |
| `/zh-Hans/` | 简体中文 | `zh-Hans/index.html` |
| `/zh-Hant/` | 繁體中文（台湾用词） | `zh-Hant/index.html` |

三页共用 `styles.css` 和 `main.js`（资源路径都是绝对的 `/...`，所以从子目录也能取到）。

改动时注意：

- **新增页面必须同时加进 `vite.config.js` 的 `build.rollupOptions.input`。** Vite 只打包列出来的
  HTML 入口，漏了就会静默地不出现在 `dist/`。
- 三页的 `<link rel="alternate" hreflang>` 是互指的，加语言要三页一起改。
- 页头的 `.lang-switch` 是 `<nav>`；`styles.css` 在 ≤960px 把 `nav` 藏起来，所以那条媒体查询里
  单独把 `.lang-switch` 显示回来。加新的页头元素时别踩这个。
- `main.js` 只在 `/` 上做一次 `navigator.language` 跳转，并且用 `localStorage` 记住用户点过的
  语言——手动选过之后不再自动跳。语言页自己不跳转，否则会和切换器打架。
- Hero 演示里的「简体中文 / 日本語 / Français」按钮是**演示的目标语言**，不是界面语言，
  三页都保持各语言本名不翻译。
