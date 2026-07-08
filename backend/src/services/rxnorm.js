const RXNAV_BASE = 'https://rxnav.nlm.nih.gov/REST';

/**
 * Look up a medication by name using the NLM RxNav API.
 *
 * @param {string} drugName - The drug name to look up (e.g. "Lisinopril")
 * @returns {Promise<{rxcui: number, name: string, ingredients: string[]} | null>}
 *   Resolved medication info, or null if the drug is not found or the request fails.
 */
export async function getMedicationInfo(drugName) {
  try {
    const response = await fetch(
      `${RXNAV_BASE}/rxcui.json?name=${encodeURIComponent(drugName)}`
    );
    if (!response.ok) return null;
    const data = await response.json();
    const rxcui = data.idGroup?.rxnormId?.[0];
    if (!rxcui) return null;

    const detailRes = await fetch(`${RXNAV_BASE}/rxcui/${rxcui}/properties.json`);
    const detailData = await detailRes.json();
    return {
      rxcui: parseInt(rxcui, 10),
      name: detailData.propertiesGroup?.properties?.[0]?.name || drugName,
      ingredients: [],
    };
  } catch {
    return null;
  }
}
