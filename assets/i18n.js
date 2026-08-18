(() => {
  const storageKey = "linkyee.locale";
  const root = document.documentElement;
  const locales = (() => {
    try {
      return JSON.parse(root.dataset.locales || "[]");
    } catch {
      return [];
    }
  })();

  const normalize = (locale) => locale.replace(/_/g, "-").toLowerCase();
  const normalizedLocales = new Map(locales.map((locale) => [normalize(locale), locale]));

  const saveLocale = (locale) => {
    try {
      localStorage.setItem(storageKey, locale);
    } catch {
      // Storage can be unavailable in private or restricted contexts.
    }
  };

  const savedLocale = () => {
    try {
      const locale = localStorage.getItem(storageKey);
      return locales.includes(locale) ? locale : null;
    } catch {
      return null;
    }
  };

  const browserLocale = () => {
    const preferred = navigator.languages || [navigator.language || ""];

    for (const locale of preferred) {
      const normalized = normalize(locale);
      if (normalizedLocales.has(normalized)) return normalizedLocales.get(normalized);

      const language = normalized.split("-")[0];
      const languageOnly = normalizedLocales.get(language);
      if (languageOnly) return languageOnly;

      const matchingLocale = locales.find((configured) => normalize(configured).split("-")[0] === language);
      if (matchingLocale) return matchingLocale;
    }

    return root.dataset.defaultLocale;
  };

  if (root.dataset.localeRoot === "true") {
    const basePath = window.location.pathname.replace(/\/(?:index\.html)?$/, "") || "/";
    const targetLocale = savedLocale() || browserLocale();
    const target = `${basePath.replace(/\/?$/, "/")}${encodeURIComponent(targetLocale)}${window.location.search}${window.location.hash}`;
    window.location.replace(target);
    return;
  }

  document.querySelectorAll("[data-locale]").forEach((link) => {
    link.addEventListener("click", () => saveLocale(link.dataset.locale));
  });
})();
