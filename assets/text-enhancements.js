(function () {
  const root = document.querySelector('#wax-content');
  if (!root) return;

  const skipSelector = [
    'a',
    'button',
    'script',
    'style',
    'code',
    'pre',
    'textarea',
    'select',
    'iframe',
    'strong',
    'em',
    'h1',
    'h2',
    'h3',
    'h4',
    'h5',
    'h6',
    '.case-section-label',
    '.page-kicker',
    '.visual-step'
  ].join(',');

  const museumVariants = [
    /Museo archeologico nazionale della Lomellina/g,
    /Museo archeologico Nazionale della Lomellina/g,
    /Museo Archeologico nazionale della Lomellina/g,
    /museo archeologico nazionale della Lomellina/g
  ];

  const keywords = [
    'Museo Archeologico Nazionale della Lomellina',
    'Fondo Davide Pace',
    'documentazione archivistica',
    'documentazione fotografica',
    'Antiquarium Laumellinum Antona',
    'Tomba dell’abbraccio',
    "Tomba dell'abbraccio",
    'Vigna Garaldi',
    'corredo funerario',
    'fotogrammetria digitale',
    'modello tridimensionale',
    'Davide Pace',
    'Gropello Cairoli',
    'Santo Spirito',
    'Vughera',
    'Marone',
    'Frascate',
    'MANLo',
    'IIIF',
    'WebGIS',
    'archivio',
    'territorio',
    'reperto',
    'reperti',
    'corredo',
    'scavo',
    'rinvenimento',
    'necropoli',
    'vetrina',
    'vetrine'
  ].sort((a, b) => b.length - a.length);

  const escapeRegExp = (value) => value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const keywordPattern = new RegExp(
    '(^|[^\\p{L}\\p{N}])(' + keywords.map(escapeRegExp).join('|') + ')(?=$|[^\\p{L}\\p{N}])',
    'giu'
  );
  const quotePattern = /(["“«])([^"“”«»]{2,160})(["”»])/g;
  const sepolcretoPattern = /(^|[^\p{L}\p{N}])(sepolcreto)(?=$|[^\p{L}\p{N}])/giu;

  const normalizeMuseumName = (text) => {
    let normalized = text;
    museumVariants.forEach((pattern) => {
      normalized = normalized.replace(pattern, 'Museo Archeologico Nazionale della Lomellina');
    });
    return normalized;
  };

  const appendKeywordText = (fragment, text) => {
    let source = normalizeMuseumName(text);
    let sepolcretoCursor = 0;
    let sepolcretoMatch;
    sepolcretoPattern.lastIndex = 0;

    while ((sepolcretoMatch = sepolcretoPattern.exec(source)) !== null) {
      const prefix = sepolcretoMatch[1] || '';
      const term = sepolcretoMatch[2];
      const termStart = sepolcretoMatch.index + prefix.length;

      appendStrongText(fragment, source.slice(sepolcretoCursor, termStart));

      const em = document.createElement('em');
      em.className = 'auto-quote-emphasis';
      em.textContent = '“' + term + '”';
      fragment.appendChild(em);

      sepolcretoCursor = termStart + term.length;
    }

    appendStrongText(fragment, source.slice(sepolcretoCursor));
  };

  const appendStrongText = (fragment, text) => {
    if (!text) return;

    let cursor = 0;
    let match;
    keywordPattern.lastIndex = 0;

    while ((match = keywordPattern.exec(text)) !== null) {
      const prefix = match[1] || '';
      const term = match[2];
      const termStart = match.index + prefix.length;

      fragment.appendChild(document.createTextNode(text.slice(cursor, termStart)));

      const strong = document.createElement('strong');
      strong.className = 'keyword-emphasis';
      strong.textContent = term;
      fragment.appendChild(strong);

      cursor = termStart + term.length;
    }

    fragment.appendChild(document.createTextNode(text.slice(cursor)));
  };

  const enhanceTextNode = (node) => {
    const parent = node.parentElement;
    if (!parent || parent.closest(skipSelector)) return;

    const original = node.nodeValue;
    const normalized = normalizeMuseumName(original);
    const shouldEnhance = quotePattern.test(normalized) ||
      sepolcretoPattern.test(normalized) ||
      keywordPattern.test(normalized) ||
      normalized !== original;

    quotePattern.lastIndex = 0;
    sepolcretoPattern.lastIndex = 0;
    keywordPattern.lastIndex = 0;

    if (!shouldEnhance) return;

    const fragment = document.createDocumentFragment();
    let cursor = 0;
    let match;

    while ((match = quotePattern.exec(normalized)) !== null) {
      appendKeywordText(fragment, normalized.slice(cursor, match.index));

      const em = document.createElement('em');
      em.className = 'auto-quote-emphasis';
      em.textContent = match[0];
      fragment.appendChild(em);

      cursor = match.index + match[0].length;
    }

    appendKeywordText(fragment, normalized.slice(cursor));
    node.replaceWith(fragment);
  };

  const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT);
  const nodes = [];
  let node;
  while ((node = walker.nextNode())) {
    if (node.nodeValue && node.nodeValue.trim()) {
      nodes.push(node);
    }
  }

  nodes.forEach(enhanceTextNode);
})();
