// NIH RxImage API — built from the C3PI dataset, free, no key required.
// Returns structured pill attributes for a given imprint code.
const RXIMAGE_BASE = 'https://rximage.nlm.nih.gov/api/rximage/1/rxbase';

export async function lookupPillByImprint(imprint) {
  try {
    const url = `${RXIMAGE_BASE}?imprint=${encodeURIComponent(imprint)}&imageSize=original`;
    const res = await fetch(url, { signal: AbortSignal.timeout(6000) });
    if (!res.ok) return null;
    const data = await res.json();
    const images = data?.nlmRxImages;
    if (!images?.length) return null;
    const first = images[0];
    const rxcui = first.rxcui ? parseInt(first.rxcui, 10) : null;
    return {
      id: `rximage-${imprint.toUpperCase()}`,
      name: first.name ?? null,
      rxcui: Number.isFinite(rxcui) ? rxcui : null,
      ndc: first.ndc11 ?? null,
      imprint: first.imprint ?? imprint,
      shape: (first.shape ?? 'unknown').toLowerCase(),
      color: (first.color ?? 'unknown').toLowerCase(),
    };
  } catch {
    return null;
  }
}
