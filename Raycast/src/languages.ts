export type TargetLanguage = {
  id: string;
  title: string;
  promptName: string;
};

// `title` 是 Raycast 界面上显示的名字。Raycast 扩展没有本地化机制、按惯例是英文界面，
// 所以这里用各语言自己的本名(endonym)，只有 "Auto" 这一项用英文——它不是语言名。
// macOS app 侧的对应表是 LinguaDock/Models/TargetLanguage.swift 的 `displayName`
// (走 String Catalog)；`promptName` 两边必须一致且保持英文，它是发给模型的载荷。
export const TARGET_LANGUAGES: TargetLanguage[] = [
  {
    id: "auto",
    title: "Auto (Chinese \u21c4 English)",
    promptName: "Automatic",
  },
  { id: "zh-Hans", title: "简体中文", promptName: "Simplified Chinese" },
  { id: "zh-Hant", title: "繁體中文", promptName: "Traditional Chinese" },
  { id: "en", title: "English", promptName: "English" },
  { id: "ja", title: "日本語", promptName: "Japanese" },
  { id: "ko", title: "한국어", promptName: "Korean" },
  { id: "es", title: "Español", promptName: "Spanish" },
  { id: "fr", title: "Français", promptName: "French" },
  { id: "de", title: "Deutsch", promptName: "German" },
  { id: "pt", title: "Português", promptName: "Portuguese" },
  { id: "it", title: "Italiano", promptName: "Italian" },
  { id: "ru", title: "Русский", promptName: "Russian" },
  { id: "ar", title: "العربية", promptName: "Arabic" },
  { id: "hi", title: "हिन्दी", promptName: "Hindi" },
  { id: "th", title: "ไทย", promptName: "Thai" },
  { id: "vi", title: "Tiếng Việt", promptName: "Vietnamese" },
  { id: "id", title: "Bahasa Indonesia", promptName: "Indonesian" },
  { id: "ms", title: "Bahasa Melayu", promptName: "Malay" },
  { id: "tr", title: "Türkçe", promptName: "Turkish" },
  { id: "nl", title: "Nederlands", promptName: "Dutch" },
  { id: "pl", title: "Polski", promptName: "Polish" },
  { id: "uk", title: "Українська", promptName: "Ukrainian" },
];

export function getTargetLanguage(id: string): TargetLanguage {
  return (
    TARGET_LANGUAGES.find((language) => language.id === id) ??
    TARGET_LANGUAGES[0]
  );
}
