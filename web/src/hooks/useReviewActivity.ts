import { type Session } from '@supabase/supabase-js'
import { useCallback, useEffect, useMemo, useState } from 'react'
import {
  parseBlogReview,
  parseReviewLikeEntries,
  type BlogReview,
  type ReviewLikeEntry,
} from '../api/reviews'
import { cleanText } from '../lib/format'
import { supabase } from '../lib/supabase'

const USER_SELECT_COLUMNS = 'id,email,review_likes,recent_visits'
const REVIEW_SELECT_COLUMNS =
  'id,name,review_title,review_description,review_bloggername,review_url,review_postdate,is_ad_electra_pred,is_ad_finetuned_pred,is_ad_llm_pred,likes,store_id,category_name,category_group_code,category_group_name,phone,address_name,road_address_name,place_url'
const MAX_RECENT_REVIEWS = 30

type ReviewReaction = {
  reviewId: string
  likedAt: string
  updatedAt: string
}

type RecentVisit = {
  reviewId: string
  name: string
  review_url: string
  review_title: string
  review_description: string
  visitedAt: string
}

type ReviewUserRow = {
  id: number
  email: string
  reviewLikes: Record<string, ReviewReaction>
  recentVisits: Record<string, RecentVisit>
}

export type ReviewLikeViewState = {
  isLiked: boolean
  likeCount: number
  isSaving: boolean
}

export type LikedReviewItem = BlogReview & {
  likedAt: string
}

export type RecentReviewItem = {
  reviewId: string
  name: string
  title: string
  description: string
  reviewUrl: string
  visitedAt: string
}

export type ReviewCollectionState<T> = {
  items: T[]
  isLoading: boolean
  errorMessage: string
  hasLoaded: boolean
}

export function reviewActivityKey(review: Pick<BlogReview, 'id' | 'reviewId' | 'url'>) {
  return review.url || review.reviewId || String(review.id)
}

function emptyCollectionState<T>(): ReviewCollectionState<T> {
  return { items: [], isLoading: false, errorMessage: '', hasLoaded: false }
}

function requireSupabaseClient() {
  if (!supabase) {
    throw new Error('Supabase 설정이 없습니다')
  }
  return supabase
}

function sessionEmail(authSession: Session | null) {
  return authSession?.user?.email?.trim() ?? ''
}

function normalizeDateText(value: unknown) {
  const text = cleanText(value)
  return text || new Date().toISOString()
}

function normalizeReviewLikes(value: unknown): Record<string, ReviewReaction> {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return {}

  const reactions: Record<string, ReviewReaction> = {}
  for (const [key, item] of Object.entries(value)) {
    const reviewId = cleanText(key)
    if (!reviewId) continue
    const source =
      item && typeof item === 'object' && !Array.isArray(item)
        ? (item as Record<string, unknown>)
        : {}
    const updatedAt = normalizeDateText(source.updatedAt)
    reactions[reviewId] = {
      reviewId,
      likedAt: cleanText(source.likedAt) || updatedAt,
      updatedAt,
    }
  }
  return reactions
}

function normalizeRecentVisits(value: unknown): Record<string, RecentVisit> {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return {}

  const recentVisits: Record<string, RecentVisit> = {}
  for (const [key, item] of Object.entries(value)) {
    const reviewId = cleanText(key)
    if (!reviewId || !item || typeof item !== 'object' || Array.isArray(item)) {
      continue
    }
    const source = item as Record<string, unknown>
    const reviewUrl = cleanText(source.review_url ?? source.reviewUrl)
    if (!reviewUrl) continue
    recentVisits[reviewId] = {
      reviewId,
      name: cleanText(source.name),
      review_url: reviewUrl,
      review_title: cleanText(source.review_title ?? source.reviewTitle),
      review_description: cleanText(
        source.review_description ?? source.reviewDescription,
      ),
      visitedAt: normalizeDateText(source.visitedAt ?? source.visited_at),
    }
  }
  return limitRecentVisits(recentVisits)
}

function normalizeUserRow(row: Record<string, unknown>): ReviewUserRow {
  const id = Number(row.id)
  if (!Number.isFinite(id)) {
    throw new Error('사용자 id를 확인할 수 없습니다')
  }

  return {
    id,
    email: cleanText(row.email),
    reviewLikes: normalizeReviewLikes(row.review_likes),
    recentVisits: normalizeRecentVisits(row.recent_visits),
  }
}

function limitRecentVisits(recentVisits: Record<string, RecentVisit>) {
  return Object.fromEntries(
    Object.entries(recentVisits)
      .sort((a, b) => b[1].visitedAt.localeCompare(a[1].visitedAt))
      .slice(0, MAX_RECENT_REVIEWS),
  )
}

function hasUserLike(likes: ReviewLikeEntry[], userId: number) {
  return likes.some((entry) => entry.user_id === userId)
}

function nextLikedEntries(likes: ReviewLikeEntry[], userId: number, isLiked: boolean) {
  const filtered = likes.filter((entry) => entry.user_id !== userId)
  if (!isLiked) return filtered

  const now = new Date().toISOString()
  return [
    ...filtered,
    {
      user_id: userId,
      likedAt: now,
      updatedAt: now,
    },
  ]
}

function recentVisitItems(recentVisits: Record<string, RecentVisit>): RecentReviewItem[] {
  return Object.values(recentVisits)
    .sort((a, b) => b.visitedAt.localeCompare(a.visitedAt))
    .map((item) => ({
      reviewId: item.reviewId,
      name: item.name,
      title: item.review_title,
      description: item.review_description,
      reviewUrl: item.review_url,
      visitedAt: item.visitedAt,
    }))
}

function likedAtForReview(
  review: BlogReview,
  user: ReviewUserRow,
  accountLikes: Record<string, ReviewReaction>,
) {
  const accountLikedAt = accountLikes[review.reviewId]?.likedAt
  const rowLikedAt = review.likes.find((entry) => entry.user_id === user.id)?.likedAt
  return accountLikedAt || rowLikedAt || ''
}

async function maybeFetchReviewByUrl(
  client: NonNullable<typeof supabase>,
  reviewUrl: string,
) {
  if (!reviewUrl) return null

  const { data, error } = await client
    .from('reviews')
    .select(REVIEW_SELECT_COLUMNS)
    .eq('review_url', reviewUrl)
    .maybeSingle()

  if (error) throw error
  return data ? parseBlogReview(data as Record<string, unknown>) : null
}

async function maybeFetchReviewById(
  client: NonNullable<typeof supabase>,
  reviewId: string,
) {
  const normalizedReviewId = reviewId.trim()
  if (!normalizedReviewId) return null

  const { data, error } = await client
    .from('reviews')
    .select(REVIEW_SELECT_COLUMNS)
    .eq('id', normalizedReviewId)
    .maybeSingle()

  if (error) throw error
  return data ? parseBlogReview(data as Record<string, unknown>) : null
}

async function resolveReviewRow(
  client: NonNullable<typeof supabase>,
  review: BlogReview,
) {
  return (
    (await maybeFetchReviewByUrl(client, review.url)) ||
    (await maybeFetchReviewById(client, review.reviewId))
  )
}

async function fetchReviewsByIds(
  client: NonNullable<typeof supabase>,
  reviewIds: string[],
) {
  const ids = [...new Set(reviewIds.map((id) => id.trim()).filter(Boolean))]
  if (ids.length === 0) return []

  const { data, error } = await client
    .from('reviews')
    .select(REVIEW_SELECT_COLUMNS)
    .in('id', ids)
    .limit(200)

  if (error) throw error
  return ((data ?? []) as Record<string, unknown>[]).map(parseBlogReview)
}

async function fetchDirectlyLikedReviews(
  client: NonNullable<typeof supabase>,
  userId: number,
) {
  const { data, error } = await client
    .from('reviews')
    .select(REVIEW_SELECT_COLUMNS)
    .contains('likes', [{ user_id: userId }])
    .limit(200)

  if (error) return []
  return ((data ?? []) as Record<string, unknown>[]).map(parseBlogReview)
}

export function useReviewActivity(
  authSession: Session | null,
  isTemporaryAdmin: boolean,
  showToast: (message: string) => void,
) {
  const [currentUser, setCurrentUser] = useState<ReviewUserRow | null>(null)
  const [reviewStates, setReviewStates] = useState<Record<string, ReviewLikeViewState>>({})
  const [likedReviewsState, setLikedReviewsState] =
    useState<ReviewCollectionState<LikedReviewItem>>(() =>
      emptyCollectionState<LikedReviewItem>(),
    )
  const [recentReviewsState, setRecentReviewsState] =
    useState<ReviewCollectionState<RecentReviewItem>>(() =>
      emptyCollectionState<RecentReviewItem>(),
    )

  const isAvailable = Boolean(supabase && authSession && !isTemporaryAdmin)

  const ensureCurrentUser = useCallback(async () => {
    const client = requireSupabaseClient()
    const email = sessionEmail(authSession)
    if (!email || isTemporaryAdmin) {
      throw new Error('Google 로그인 후 사용할 수 있습니다')
    }

    const { data, error } = await client
      .from('users')
      .select(USER_SELECT_COLUMNS)
      .eq('email', email)
      .maybeSingle()

    if (error) throw error
    if (data) {
      const user = normalizeUserRow(data as Record<string, unknown>)
      setCurrentUser(user)
      return user
    }

    const { data: created, error: createError } = await client
      .from('users')
      .insert({ email, review_likes: {}, recent_visits: {} })
      .select(USER_SELECT_COLUMNS)
      .single()

    if (createError) throw createError
    const user = normalizeUserRow(created as Record<string, unknown>)
    setCurrentUser(user)
    return user
  }, [authSession, isTemporaryAdmin])

  const updateUserReviewLikes = useCallback(
    async (user: ReviewUserRow, reviewLikes: Record<string, ReviewReaction>) => {
      const client = requireSupabaseClient()
      const { data, error } = await client
        .from('users')
        .update({ review_likes: reviewLikes })
        .eq('id', user.id)
        .select(USER_SELECT_COLUMNS)
        .single()

      if (error) throw error
      const updated = normalizeUserRow(data as Record<string, unknown>)
      setCurrentUser(updated)
      return updated
    },
    [],
  )

  const updateUserRecentVisits = useCallback(
    async (user: ReviewUserRow, recentVisits: Record<string, RecentVisit>) => {
      const client = requireSupabaseClient()
      const limited = limitRecentVisits(recentVisits)
      const { data, error } = await client
        .from('users')
        .update({ recent_visits: limited })
        .eq('id', user.id)
        .select(USER_SELECT_COLUMNS)
        .single()

      if (error) throw error
      const updated = normalizeUserRow(data as Record<string, unknown>)
      setCurrentUser(updated)
      return updated
    },
    [],
  )

  const setReviewStateForKeys = useCallback(
    (
      review: Pick<BlogReview, 'id' | 'reviewId' | 'url'>,
      state: ReviewLikeViewState,
    ) => {
      const keys = [
        reviewActivityKey(review),
        review.reviewId,
        review.url,
        String(review.id),
      ].filter(Boolean)

      setReviewStates((prev) => {
        const next = { ...prev }
        for (const key of keys) next[key] = state
        return next
      })
    },
    [],
  )

  const getReviewLikeState = useCallback(
    (review: BlogReview): ReviewLikeViewState => {
      const override = reviewStates[reviewActivityKey(review)]
      if (override) return override

      const isLiked = currentUser ? hasUserLike(review.likes, currentUser.id) : false
      return {
        isLiked,
        likeCount: review.likeCount,
        isSaving: false,
      }
    },
    [currentUser, reviewStates],
  )

  const toggleReviewHeart = useCallback(
    async (review: BlogReview) => {
      if (!isAvailable) {
        showToast('Google 로그인 후 사용할 수 있습니다')
        return
      }

      const key = reviewActivityKey(review)
      const previous = getReviewLikeState(review)
      setReviewStates((prev) => ({
        ...prev,
        [key]: { ...previous, isSaving: true },
      }))

      try {
        const client = requireSupabaseClient()
        const user = await ensureCurrentUser()
        const resolved = await resolveReviewRow(client, review)
        if (!resolved) {
          throw new Error('저장된 리뷰 정보를 찾지 못했습니다')
        }

        const currentLikes = parseReviewLikeEntries(resolved.likes)
        const nextIsLiked = !hasUserLike(currentLikes, user.id)
        const likes = nextLikedEntries(currentLikes, user.id, nextIsLiked)
        const { data, error } = await client
          .from('reviews')
          .update({ likes })
          .eq('id', resolved.reviewId)
          .select(REVIEW_SELECT_COLUMNS)
          .single()

        if (error) throw error

        const updatedReview = parseBlogReview(data as Record<string, unknown>)
        const now = new Date().toISOString()
        const nextAccountLikes = { ...user.reviewLikes }
        if (nextIsLiked) {
          nextAccountLikes[updatedReview.reviewId] = {
            reviewId: updatedReview.reviewId,
            likedAt: now,
            updatedAt: now,
          }
        } else {
          delete nextAccountLikes[updatedReview.reviewId]
        }
        await updateUserReviewLikes(user, nextAccountLikes)

        const nextState = {
          isLiked: nextIsLiked,
          likeCount: updatedReview.likes.length,
          isSaving: false,
        }
        setReviewStateForKeys(review, nextState)
        setReviewStateForKeys(updatedReview, nextState)
        setLikedReviewsState((prev) => ({
          ...prev,
          items: nextIsLiked
            ? prev.items
            : prev.items.filter((item) => item.reviewId !== updatedReview.reviewId),
          hasLoaded: nextIsLiked ? false : prev.hasLoaded,
        }))
      } catch (error) {
        setReviewStates((prev) => ({
          ...prev,
          [key]: { ...previous, isSaving: false },
        }))
        showToast(error instanceof Error ? error.message : '하트를 변경하지 못했습니다')
      }
    },
    [
      ensureCurrentUser,
      getReviewLikeState,
      isAvailable,
      setReviewStateForKeys,
      showToast,
      updateUserReviewLikes,
    ],
  )

  const loadLikedReviews = useCallback(async () => {
    if (!isAvailable) {
      setLikedReviewsState({ items: [], isLoading: false, errorMessage: '', hasLoaded: true })
      return
    }

    setLikedReviewsState((prev) => ({ ...prev, isLoading: true, errorMessage: '' }))
    try {
      const client = requireSupabaseClient()
      const user = await ensureCurrentUser()
      const accountReviewIds = Object.keys(user.reviewLikes)
      const [accountReviews, directReviews] = await Promise.all([
        fetchReviewsByIds(client, accountReviewIds),
        fetchDirectlyLikedReviews(client, user.id),
      ])

      const byId = new Map<string, BlogReview>()
      for (const review of [...accountReviews, ...directReviews]) {
        if (review.reviewId) byId.set(review.reviewId, review)
      }

      const accountLikes = { ...user.reviewLikes }
      for (const review of directReviews) {
        if (!accountLikes[review.reviewId] && hasUserLike(review.likes, user.id)) {
          const likedAt = likedAtForReview(review, user, accountLikes) || new Date().toISOString()
          accountLikes[review.reviewId] = {
            reviewId: review.reviewId,
            likedAt,
            updatedAt: likedAt,
          }
        }
      }
      if (Object.keys(accountLikes).length !== Object.keys(user.reviewLikes).length) {
        await updateUserReviewLikes(user, accountLikes)
      }

      const items: LikedReviewItem[] = [...byId.values()]
        .filter((review) => accountLikes[review.reviewId] || hasUserLike(review.likes, user.id))
        .map((review) => ({
          ...review,
          likedAt: likedAtForReview(review, user, accountLikes),
        }))
        .sort((a, b) => b.likedAt.localeCompare(a.likedAt))

      for (const review of items) {
        setReviewStateForKeys(review, {
          isLiked: true,
          likeCount: review.likes.length,
          isSaving: false,
        })
      }

      setLikedReviewsState({ items, isLoading: false, errorMessage: '', hasLoaded: true })
    } catch (error) {
      setLikedReviewsState({
        items: [],
        isLoading: false,
        errorMessage: error instanceof Error ? error.message : '내 하트 목록을 불러오지 못했습니다',
        hasLoaded: true,
      })
    }
  }, [ensureCurrentUser, isAvailable, setReviewStateForKeys, updateUserReviewLikes])

  const removeLikedReview = useCallback(
    async (review: Pick<BlogReview, 'id' | 'reviewId' | 'url'>) => {
      if (!isAvailable) return

      const client = requireSupabaseClient()
      const user = await ensureCurrentUser()
      const resolved =
        'title' in review
          ? await resolveReviewRow(client, review as BlogReview)
          : await maybeFetchReviewById(client, review.reviewId)
      if (!resolved) throw new Error('저장된 리뷰 정보를 찾지 못했습니다')

      const likes = parseReviewLikeEntries(resolved.likes).filter(
        (entry) => entry.user_id !== user.id,
      )

      const { error } = await client
        .from('reviews')
        .update({ likes })
        .eq('id', resolved.reviewId)

      if (error) throw error

      const nextAccountLikes = { ...user.reviewLikes }
      delete nextAccountLikes[resolved.reviewId]
      await updateUserReviewLikes(user, nextAccountLikes)

      setLikedReviewsState((prev) => ({
        ...prev,
        items: prev.items.filter((item) => item.reviewId !== resolved.reviewId),
      }))
      setReviewStateForKeys(resolved, {
        isLiked: false,
        likeCount: likes.length,
        isSaving: false,
      })
    },
    [ensureCurrentUser, isAvailable, setReviewStateForKeys, updateUserReviewLikes],
  )

  const recordRecentReview = useCallback(
    async (review: BlogReview) => {
      if (!isAvailable) {
        throw new Error('Google 로그인 후 사용할 수 있습니다')
      }

      const client = requireSupabaseClient()
      const user = await ensureCurrentUser()
      const resolved = await resolveReviewRow(client, review)
      if (!resolved) {
        throw new Error('저장된 리뷰 정보를 찾지 못했습니다')
      }

      const now = new Date().toISOString()
      const recentVisits = limitRecentVisits({
        ...user.recentVisits,
        [resolved.reviewId]: {
          reviewId: resolved.reviewId,
          name: resolved.restaurantName,
          review_url: resolved.url,
          review_title: resolved.title,
          review_description: resolved.description,
          visitedAt: now,
        },
      })

      const updated = await updateUserRecentVisits(user, recentVisits)
      setRecentReviewsState((prev) => ({
        ...prev,
        items: recentVisitItems(updated.recentVisits),
        hasLoaded: prev.hasLoaded,
      }))
    },
    [ensureCurrentUser, isAvailable, updateUserRecentVisits],
  )

  const openReviewSource = useCallback(
    async (review: BlogReview) => {
      if (!review.url) {
        showToast('연결된 리뷰 원문이 없습니다')
        return
      }

      try {
        await recordRecentReview(review)
        window.open(review.url, '_blank', 'noopener,noreferrer')
      } catch (error) {
        showToast(error instanceof Error ? error.message : '최근 기록에 저장하지 못했습니다')
      }
    },
    [recordRecentReview, showToast],
  )

  const openRecentReviewSource = useCallback(
    (review: RecentReviewItem) => {
      if (!review.reviewUrl) {
        showToast('연결된 리뷰 원문이 없습니다')
        return
      }
      window.open(review.reviewUrl, '_blank', 'noopener,noreferrer')
    },
    [showToast],
  )

  const loadRecentReviews = useCallback(async () => {
    if (!isAvailable) {
      setRecentReviewsState({ items: [], isLoading: false, errorMessage: '', hasLoaded: true })
      return
    }

    setRecentReviewsState((prev) => ({ ...prev, isLoading: true, errorMessage: '' }))
    try {
      const user = await ensureCurrentUser()
      setRecentReviewsState({
        items: recentVisitItems(user.recentVisits),
        isLoading: false,
        errorMessage: '',
        hasLoaded: true,
      })
    } catch (error) {
      setRecentReviewsState({
        items: [],
        isLoading: false,
        errorMessage: error instanceof Error ? error.message : '최근 기록을 불러오지 못했습니다',
        hasLoaded: true,
      })
    }
  }, [ensureCurrentUser, isAvailable])

  const removeRecentReview = useCallback(
    async (reviewId: string) => {
      if (!isAvailable) return

      const user = await ensureCurrentUser()
      const recentVisits = { ...user.recentVisits }
      delete recentVisits[reviewId]
      const updated = await updateUserRecentVisits(user, recentVisits)
      setRecentReviewsState((prev) => ({
        ...prev,
        items: recentVisitItems(updated.recentVisits),
      }))
    },
    [ensureCurrentUser, isAvailable, updateUserRecentVisits],
  )

  const clearRecentReviews = useCallback(async () => {
    if (!isAvailable) return

    const user = await ensureCurrentUser()
    await updateUserRecentVisits(user, {})
    setRecentReviewsState({ items: [], isLoading: false, errorMessage: '', hasLoaded: true })
  }, [ensureCurrentUser, isAvailable, updateUserRecentVisits])

  useEffect(() => {
    setCurrentUser(null)
    setReviewStates({})
    setLikedReviewsState(emptyCollectionState())
    setRecentReviewsState(emptyCollectionState())
    if (!isAvailable) return

    void ensureCurrentUser().catch(() => {})
  }, [authSession?.access_token, ensureCurrentUser, isAvailable])

  return useMemo(
    () => ({
      isAvailable,
      likedReviewsState,
      recentReviewsState,
      getReviewLikeState,
      toggleReviewHeart,
      loadLikedReviews,
      removeLikedReview,
      openReviewSource,
      openRecentReviewSource,
      loadRecentReviews,
      removeRecentReview,
      clearRecentReviews,
    }),
    [
      clearRecentReviews,
      getReviewLikeState,
      isAvailable,
      likedReviewsState,
      loadLikedReviews,
      loadRecentReviews,
      openRecentReviewSource,
      openReviewSource,
      recentReviewsState,
      removeLikedReview,
      removeRecentReview,
      toggleReviewHeart,
    ],
  )
}
