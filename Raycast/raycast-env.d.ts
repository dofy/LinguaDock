/// <reference types="@raycast/api">

/* 🚧 🚧 🚧
 * This file is auto-generated from the extension's manifest.
 * Do not modify manually. Instead, update the `package.json` file.
 * 🚧 🚧 🚧 */

/* eslint-disable @typescript-eslint/ban-types */

type ExtensionPreferences = {
  /** API Base URL - OpenAI-compatible version root or full chat completions URL */
  "apiBaseUrl": string,
  /** API Key - API key for the configured OpenAI-compatible service */
  "apiKey": string,
  /** Model - Model identifier sent to the API */
  "model": string,
  /** Default Target Language - Initial target language in the translation form */
  "defaultTargetLanguage": "auto" | "zh-Hans" | "zh-Hant" | "en" | "ja" | "ko" | "es" | "fr" | "de" | "pt" | "it" | "ru" | "ar" | "hi" | "th" | "vi" | "id" | "ms" | "tr" | "nl" | "pl" | "uk"
}

/** Preferences accessible in all the extension's commands */
declare type Preferences = ExtensionPreferences

declare namespace Preferences {
  /** Preferences accessible in the `translate` command */
  export type Translate = ExtensionPreferences & {}
}

declare namespace Arguments {
  /** Arguments passed to the `translate` command */
  export type Translate = {}
}
