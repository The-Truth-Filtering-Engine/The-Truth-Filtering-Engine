export function cleanText(value: unknown) {
  return String(value ?? '')
    .replace(/<[^>]*>/g, '')
    .replace(/&quot;/g, '"')
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .trim()
}

export function cleanExternalUrl(value: unknown) {
  const url = cleanText(value)
  return /^https?:\/\//i.test(url) ? url : ''
}

export function cleanImageUrl(value: unknown) {
  const url = cleanText(value)
  return /^(https?:\/\/|\/)/i.test(url) ? url : ''
}

export function formatDistance(distance: number) {
  if (!Number.isFinite(distance) || distance <= 0) return '거리 정보 없음'
  if (distance >= 1000) return `${(distance / 1000).toFixed(1)}km`
  return `${Math.round(distance)}m`
}

export function formatReviewDate(value: unknown) {
  const raw = cleanText(value)
  if (/^\d{8}$/.test(raw)) {
    return `${raw.slice(0, 4)}.${raw.slice(4, 6)}.${raw.slice(6, 8)}`
  }
  return raw
}

export function formatAdScore(adScore: number) {
  if (!Number.isFinite(adScore)) return '정보 없음'
  return `${Math.round(Math.max(0, Math.min(1, adScore)) * 100)}%`
}
