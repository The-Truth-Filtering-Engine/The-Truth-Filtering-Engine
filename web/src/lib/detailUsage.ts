import { type UserProfile } from '../api/user'
import { getRestaurantStoreId, type Restaurant } from './restaurant'

const ANALYSIS_COIN_COST = 100
const ANALYSIS_FREE_WINDOW_DAYS = 2
const DAY_IN_MS = 24 * 60 * 60 * 1000

function getKoreaDateSerial(date = new Date()) {
  const parts = new Intl.DateTimeFormat('en-US', {
    timeZone: 'Asia/Seoul',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).formatToParts(date)

  const year = Number(parts.find((part) => part.type === 'year')?.value)
  const month = Number(parts.find((part) => part.type === 'month')?.value)
  const day = Number(parts.find((part) => part.type === 'day')?.value)

  if (!Number.isFinite(year) || !Number.isFinite(month) || !Number.isFinite(day)) {
    return null
  }

  return Math.floor(Date.UTC(year, month - 1, day) / DAY_IN_MS)
}

function parseStoreDateSerial(value: unknown) {
  const dateText = String(value ?? '').trim()
  if (!/^\d{8}$/.test(dateText)) return null

  const year = Number(dateText.slice(0, 4))
  const month = Number(dateText.slice(4, 6))
  const day = Number(dateText.slice(6, 8))
  if (!Number.isFinite(year) || !Number.isFinite(month) || !Number.isFinite(day)) {
    return null
  }

  return Math.floor(Date.UTC(year, month - 1, day) / DAY_IN_MS)
}

function getFreeDetailRemainingDays(restaurant: Restaurant, storeValue: unknown) {
  const storeId = getRestaurantStoreId(restaurant)
  if (!storeId || !storeValue || typeof storeValue !== 'object' || Array.isArray(storeValue)) {
    return null
  }

  const storedDateSerial = parseStoreDateSerial(
    (storeValue as Record<string, unknown>)[storeId],
  )
  const todaySerial = getKoreaDateSerial()
  if (storedDateSerial === null || todaySerial === null) return null

  const elapsedDays = Math.max(0, todaySerial - storedDateSerial)
  if (elapsedDays >= ANALYSIS_FREE_WINDOW_DAYS) return null

  return Math.max(1, ANALYSIS_FREE_WINDOW_DAYS - elapsedDays - 1)
}

export function getDetailUsageInfo(restaurant: Restaurant, profile: UserProfile | null) {
  if (!profile) return { label: '상세 보기', canAnalyze: true }

  const remainingFreeDays = getFreeDetailRemainingDays(restaurant, profile.store)
  if (remainingFreeDays !== null) {
    return { label: `상세 보기 (무료-${remainingFreeDays}일 남음)`, canAnalyze: true }
  }

  if (profile.freecount > 0 || profile.premiumcount > 0) {
    return { label: '상세 보기 (분석횟수 -1회)', canAnalyze: true }
  }

  if (profile.coin >= ANALYSIS_COIN_COST) {
    return { label: `상세 보기 (-${ANALYSIS_COIN_COST} coin)`, canAnalyze: true }
  }

  return { label: '상세 보기', canAnalyze: false }
}
