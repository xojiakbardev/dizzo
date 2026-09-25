// vue-i18n options (the messages themselves are in i18n/locales/<lang>/).
export default defineI18nConfig(() => ({
  legacy: false,
  fallbackLocale: 'uz',
  // Russian plurals: 1 товар, 2 товара, 5 товаров.
  pluralRules: {
    ru: (choice: number, choicesLength: number) => {
      if (choicesLength < 3) return choice === 1 ? 0 : 1;
      const tens = choice % 100;
      const ones = choice % 10;
      if (tens > 10 && tens < 20) return 2;
      if (ones === 1) return 0;
      if (ones >= 2 && ones <= 4) return 1;
      return 2;
    },
  },
  missingWarn: false,
  fallbackWarn: false,
}));
