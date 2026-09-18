const extension = {
  actions: ({ text }) => {
    const value = text.trim()
    return [
      {
        title: {
          en: 'Translate with LinguaDock',
          'zh-hans': '用 LinguaDock 翻译',
          'zh-hant': '用 LinguaDock 翻譯',
        },
        code() {
          popclip.openUrl(
            `linguadock://translate?text=${encodeURIComponent(value)}`
          )
        },
      },
    ]
  },
}

export default extension
