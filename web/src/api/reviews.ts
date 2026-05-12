import { BACKEND_BASE_URL } from '../config'
import { cleanText, cleanExternalUrl, formatReviewDate } from '../lib/format'
import { type Restaurant } from '../lib/restaurant'

export type ReviewGrade = 'real' | 'suspicious' | 'ad'

export type BlogReview = {
  id: number
  title: string
  author: string
  date: string
  preview: string
  url: string
  adScore: number | null
  adProbability: number
  grade: ReviewGrade
}

export type DetailData = {
  reviews: BlogReview[]
  keywords: Array<{ word: string; count: number }>
}

export type AnalysisUsage = {
  charged?: boolean
  chargedBy?: 'freecount' | 'premiumcount' | 'coin' | null
  profile?: Record<string, unknown> | null
}

export type DetailJson = {
  reviews?: Record<string, unknown>[]
  hasMore?: boolean
  usage?: AnalysisUsage
}

export type ReviewStreamChunk = {
  reviews?: Record<string, unknown>[]
  done?: boolean
  naverQuery?: string
}

export const REVIEW_BATCH_SIZE = 100
export const REVIEW_PAGE_SIZE = 10
export const MAX_REVIEW_RESULTS = 300

export class ApiRequestError extends Error {
  status: number

  constructor(message: string, status: number) {
    super(message)
    this.name = 'ApiRequestError'
    this.status = status
  }
}

export function isAnalysisUsageRequiredError(error: unknown) {
  return error instanceof ApiRequestError && error.status === 402
}

export function gradeFromScore(adScore: number | null): ReviewGrade {
  if (adScore === null) return 'suspicious'
  if (adScore >= 0.6) return 'ad'
  if (adScore >= 0.3) return 'suspicious'
  return 'real'
}

export function gradeLabel(grade: ReviewGrade) {
  if (grade === 'real') return '진성'
  if (grade === 'ad') return '광고'
  return '의심'
}

export function parseBlogReview(item: Record<string, unknown>): BlogReview {
  const electraPred =
    typeof item.is_ad_electra_pred === 'number' ? item.is_ad_electra_pred : null
  const scoreSource =
    typeof item.is_ad_finetuned_pred === 'number'
      ? item.is_ad_finetuned_pred
      : typeof item.is_ad_llm_pred === 'number'
        ? item.is_ad_llm_pred
        : electraPred === 1
          ? 0.9
          : electraPred === 0
            ? 0.1
            : null
  const adScore = scoreSource === null ? null : Math.max(0, Math.min(1, scoreSource))
  const description = cleanText(item.review_description)
  const preview = description
    ? description.length > 96
      ? `${description.slice(0, 96)}...`
      : description
    : '요약 없음'

  return {
    id: Number(item.id ?? 0),
    title: cleanText(item.review_title) || '(제목 없음)',
    author: cleanText(item.review_bloggername) || '알 수 없음',
    date: formatReviewDate(item.review_postdate),
    preview,
    url: cleanExternalUrl(item.review_url ?? item.reviewUrl ?? item.link),
    adScore,
    adProbability: adScore === null ? 50 : Math.round(adScore * 100),
    grade: gradeFromScore(adScore),
  }
}

export function buildKeywords(reviews: BlogReview[]) {
  const stopWords = new Set([
    '맛집', '추천', '후기', '방문', '리뷰', '정말', '너무',
    '있는', '없는', '그리고', '에서', '으로', '하고', '까지',
    '강남', '카페',
  ])
  const counts = new Map<string, number>()

  for (const review of reviews) {
    const words = review.title
      .replace(/[^\p{L}\p{N}\s]/gu, ' ')
      .split(/\s+/)
      .map((word) => word.trim())
      .filter((word) => word.length >= 2 && !stopWords.has(word))

    for (const word of words) {
      counts.set(word, (counts.get(word) ?? 0) + 1)
    }
  }

  return [...counts.entries()]
    .sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0]))
    .slice(0, 14)
    .map(([word, count]) => ({ word, count }))
}

export function mergeReviews(current: BlogReview[], incoming: BlogReview[]) {
  const byKey = new Map<string, BlogReview>()

  for (const review of current) {
    byKey.set(review.url || `id:${review.id}`, review)
  }
  for (const review of incoming) {
    byKey.set(review.url || `id:${review.id}`, review)
  }

  return [...byKey.values()]
}

async function readErrorMessage(response: Response) {
  try {
    const data = (await response.json()) as { detail?: unknown }
    return cleanText(data.detail) || `요청 실패: ${response.status}`
  } catch {
    return `요청 실패: ${response.status}`
  }
}

export async function* streamReviews(
  path: string,
  signal: AbortSignal,
  accessToken?: string,
): AsyncGenerator<ReviewStreamChunk> {
  const response = await fetch(`${BACKEND_BASE_URL}${path}`, {
    signal,
    headers: accessToken ? { Authorization: `Bearer ${accessToken}` } : undefined,
  })
  if (!response.ok) {
    throw new ApiRequestError(await readErrorMessage(response), response.status)
  }
  if (!response.body) {
    throw new ApiRequestError('스트리밍 응답을 읽을 수 없습니다', response.status)
  }

  const reader = response.body.getReader()
  const decoder = new TextDecoder()
  let buffer = ''

  try {
    while (true) {
      const { done, value } = await reader.read()
      if (done) break
      buffer += decoder.decode(value, { stream: true })
      const parts = buffer.split('\n\n')
      buffer = parts.pop() ?? ''
      for (const part of parts) {
        const line = part.trim()
        if (line.startsWith('data: ')) {
          yield JSON.parse(line.slice(6)) as ReviewStreamChunk
        }
      }
    }
  } finally {
    reader.releaseLock()
  }
}

export async function fetchDetailJson(
  path: string,
  signal: AbortSignal,
  accessToken?: string,
): Promise<DetailJson> {
  const response = await fetch(`${BACKEND_BASE_URL}${path}`, {
    signal,
    headers: accessToken ? { Authorization: `Bearer ${accessToken}` } : undefined,
  })
  if (!response.ok) {
    throw new ApiRequestError(await readErrorMessage(response), response.status)
  }
  return (await response.json()) as DetailJson
}

export function buildReviewSearchPath(
  endpoint: '/api/search' | '/api/search/cached' | '/api/search/reviews' | '/api/search/stream',
  query: string,
  options: {
    naverStart?: number
    refresh?: boolean
    limit?: number
    maxResults?: number
    restaurant?: Restaurant
  } = {},
) {
  const params = new URLSearchParams({
    query,
    limit: String(options.limit ?? REVIEW_BATCH_SIZE),
  })
  const restaurant = options.restaurant

  if (restaurant) {
    const storeId = restaurant.storeId || restaurant.id
    if (storeId) params.set('storeId', storeId)
    if (restaurant.categoryName) params.set('categoryName', restaurant.categoryName)
    if (restaurant.categoryGroupCode) {
      params.set('categoryGroupCode', restaurant.categoryGroupCode)
    }
    if (restaurant.categoryGroupName) {
      params.set('categoryGroupName', restaurant.categoryGroupName)
    }
    if (restaurant.phone) params.set('phone', restaurant.phone)
    if (restaurant.addressName) params.set('addressName', restaurant.addressName)
    if (restaurant.roadAddressName) {
      params.set('roadAddressName', restaurant.roadAddressName)
    }
    if (restaurant.placeUrl || restaurant.link) {
      params.set('placeUrl', restaurant.placeUrl || restaurant.link)
    }
  }

  if (endpoint === '/api/search' || endpoint === '/api/search/stream') {
    params.set('mode', 'model')
    params.set('naverStart', String(options.naverStart ?? 1))
    params.set('maxResults', String(options.maxResults ?? MAX_REVIEW_RESULTS))
    if (options.refresh) params.set('refresh', 'true')
  } else {
    params.set('limit', String(options.maxResults ?? MAX_REVIEW_RESULTS))
  }

  return `${endpoint}?${params.toString()}`
}
