import {
  Bookmark,
  Clock,
  Coins,
  Crown,
  LocateFixed,
  Search,
  Settings,
  Sparkles,
  Zap,
} from 'lucide-react'
import { type FormEvent, type ReactNode, useEffect, useRef, useState } from 'react'
import appLogoUrl from '../logo.png'
import { supabase } from './lib/supabase'

import {
  type Restaurant,
  type AiRecommendItem,
  type RecentAnalysisItem,
  aiRecommendToRestaurant,
  parseAiRecommendItem,
  recentAnalysisToRestaurant,
} from './lib/restaurant'
import { fetchSearchRestaurants } from './api/places'
import { fetchUserProfile, fetchRecentAnalyses, updateUserPremium, chargeUserCoins, type RecentAnalyses, type UserProfile } from './api/user'
import { cleanText } from './lib/format'
import { getDetailUsageInfo } from './lib/detailUsage'
import { useAuth } from './hooks/useAuth'
import { useBookmarks } from './hooks/useBookmarks'
import { useDetail } from './hooks/useDetail'
import { useMap } from './hooks/useMap'
import { useReviewActivity } from './hooks/useReviewActivity'
import { LoginPanel } from './components/panels/LoginPanel'
import { SearchPanel } from './components/panels/SearchPanel'
import { RestaurantPanel } from './components/panels/RestaurantPanel'
import { DetailPanel } from './components/panels/DetailPanel'
import { BookmarkPanel } from './components/panels/BookmarkPanel'
import { RecentPanel } from './components/panels/RecentPanel'
import { AiPanel, type AiRecommendState, type AiRegionScope } from './components/panels/AiPanel'
import { SettingsPanel } from './components/panels/SettingsPanel'
import { BACKEND_BASE_URL } from './config'

type ActiveSidePanel =
  | 'search'
  | 'restaurant'
  | 'bookmarks'
  | 'recent'
  | 'detail'
  | 'ai'
  | 'settings'

type UserProfileState = {
  profile: UserProfile | null
  isLoading: boolean
  isSaving: boolean
  errorMessage: string
  hasLoaded: boolean
}

type RecentAnalysesState = {
  data: RecentAnalyses | null
  isLoading: boolean
  errorMessage: string
  hasLoaded: boolean
}

function App() {
  const [toastMessage, setToastMessage] = useState('')
  const [showIntroSplash, setShowIntroSplash] = useState(true)
  const [activeSidePanel, setActiveSidePanel] = useState<ActiveSidePanel>('search')
  const [selectedRestaurant, setSelectedRestaurant] = useState<Restaurant | null>(null)
  const [searchInput, setSearchInput] = useState('')
  const [searchQuery, setSearchQuery] = useState('')
  const [searchResults, setSearchResults] = useState<Restaurant[]>([])
  const [searchState, setSearchState] = useState<'idle' | 'loading' | 'loaded' | 'error'>('idle')
  const [searchErrorMessage, setSearchErrorMessage] = useState('')
  const searchRequestIdRef = useRef(0)
  const [userProfileState, setUserProfileState] = useState<UserProfileState>({
    profile: null,
    isLoading: false,
    isSaving: false,
    errorMessage: '',
    hasLoaded: false,
  })
  const [recentAnalysesState, setRecentAnalysesState] = useState<RecentAnalysesState>({
    data: null,
    isLoading: false,
    errorMessage: '',
    hasLoaded: false,
  })
  const [aiRegionScope, setAiRegionScope] = useState<AiRegionScope>('si')
  const [aiRecommendState, setAiRecommendState] = useState<AiRecommendState>({
    items: [],
    page: 1,
    hasNext: false,
    isLoading: false,
    errorMessage: '',
    hasLoaded: false,
    regionLabel: '',
    currentRegionLabel: '',
    currentRegionSi: '',
    currentRegionGu: '',
    currentRegionDong: '',
    isRegionFiltered: false,
  })

  function showToast(message: string) {
    setToastMessage(message)
    window.setTimeout(() => setToastMessage(''), 1800)
  }

  function resetUserProfileState() {
    setUserProfileState({ profile: null, isLoading: false, isSaving: false, errorMessage: '', hasLoaded: false })
  }

  function resetRecentAnalysesState() {
    setRecentAnalysesState({ data: null, isLoading: false, errorMessage: '', hasLoaded: false })
  }

  function handleSignOut() {
    resetUserProfileState()
    resetRecentAnalysesState()
    setSelectedRestaurant(null)
    setActiveSidePanel('search')
  }

  const auth = useAuth(handleSignOut, showToast)

  const bookmarks = useBookmarks(auth.authHeaders, auth.authKey, showToast)
  const reviewActivity = useReviewActivity(
    auth.authEmail,
    showToast,
  )

  function handleProfileRefresh(profile: UserProfile) {
    setUserProfileState((prev) => ({
      ...prev,
      profile,
      isLoading: false,
      isSaving: false,
      errorMessage: '',
      hasLoaded: true,
    }))
    setRecentAnalysesState((prev) => ({ ...prev, hasLoaded: false }))
  }

  const detail = useDetail(auth.authHeaders, showToast, handleProfileRefresh)

  function handleMapSelectRestaurant(restaurant: Restaurant | null) {
    if (!restaurant) {
      setSelectedRestaurant(null)
      setActiveSidePanel('search')
      return
    }
    setSelectedRestaurant(restaurant)
    setActiveSidePanel('restaurant')
  }

  const map = useMap(handleMapSelectRestaurant, showToast)

  useEffect(() => {
    const timer = window.setTimeout(() => setShowIntroSplash(false), 4700)
    return () => window.clearTimeout(timer)
  }, [])

  useEffect(() => {
    if (
      !auth.hasApiAuth ||
      userProfileState.hasLoaded ||
      userProfileState.isLoading ||
      userProfileState.errorMessage
    ) {
      return
    }
    void loadUserProfile()
  }, [
    auth.authKey,
    auth.hasApiAuth,
    userProfileState.errorMessage,
    userProfileState.hasLoaded,
    userProfileState.isLoading,
  ])

  async function loadUserProfile() {
    if (!auth.hasApiAuth) {
      resetUserProfileState()
      return
    }

    setUserProfileState((prev) => ({ ...prev, isLoading: true, errorMessage: '' }))

    try {
      const profile = await fetchUserProfile(auth.authHeaders)
      setUserProfileState({ profile, isLoading: false, isSaving: false, errorMessage: '', hasLoaded: true })
    } catch (error) {
      setUserProfileState((prev) => ({
        ...prev,
        isLoading: false,
        isSaving: false,
        errorMessage: error instanceof Error ? error.message : '사용자 정보를 불러오지 못했습니다',
        hasLoaded: true,
      }))
    }
  }

  async function toggleUserPremium() {
    const profile = userProfileState.profile
    if (!auth.hasApiAuth || !profile) return

    setUserProfileState((prev) => ({ ...prev, isSaving: true, errorMessage: '' }))

    try {
      const updated = await updateUserPremium(auth.authHeaders, profile.premium !== 1)
      setUserProfileState({ profile: updated, isLoading: false, isSaving: false, errorMessage: '', hasLoaded: true })
      showToast(updated.premium === 1 ? '프리미엄이 설정되었습니다' : '프리미엄이 해제되었습니다')
    } catch (error) {
      setUserProfileState((prev) => ({
        ...prev,
        isSaving: false,
        errorMessage: error instanceof Error ? error.message : '프리미엄 상태를 변경하지 못했습니다',
      }))
    }
  }

  async function chargeCoins(amount: number) {
    if (!auth.hasApiAuth) return

    setUserProfileState((prev) => ({ ...prev, isSaving: true, errorMessage: '' }))

    try {
      const updated = await chargeUserCoins(auth.authHeaders, amount)
      setUserProfileState({ profile: updated, isLoading: false, isSaving: false, errorMessage: '', hasLoaded: true })
      showToast(`${amount.toLocaleString()} 코인이 충전되었습니다`)
    } catch (error) {
      setUserProfileState((prev) => ({
        ...prev,
        isSaving: false,
        errorMessage: error instanceof Error ? error.message : '코인을 충전하지 못했습니다',
      }))
    }
  }

  async function copyToClipboard(value: string, successMessage: string) {
    try {
      await navigator.clipboard.writeText(value)
      showToast(successMessage)
    } catch {
      showToast('클립보드 복사에 실패했습니다')
    }
  }

  function handleCall(restaurant: Restaurant) {
    if (!restaurant.phone.trim()) {
      showToast('등록된 전화번호가 없습니다')
      return
    }
    copyToClipboard(restaurant.phone, '전화번호가 복사되었습니다')
  }

  function handleRoute(restaurant: Restaurant) {
    if (!restaurant.link.trim()) {
      showToast('길찾기 링크가 없습니다')
      return
    }
    window.open(restaurant.link, '_blank', 'noopener,noreferrer')
  }

  function handleShare(restaurant: Restaurant) {
    if (!restaurant.link.trim()) {
      showToast('공유 가능한 링크가 없습니다')
      return
    }
    copyToClipboard(restaurant.link, '링크가 복사되었습니다')
  }

  function openDetailPanel(restaurant: Restaurant, forceFresh = false) {
    setSelectedRestaurant(restaurant)
    setActiveSidePanel('detail')
    detail.loadRestaurantDetail(restaurant, forceFresh)
  }

  function handleDetailButtonClick(restaurant: Restaurant) {
    const usageInfo = getDetailUsageInfo(restaurant, userProfileState.profile)
    if (!usageInfo.canAnalyze) {
      showToast('분석을 위해 코인을 충전해주세요')
      setSelectedRestaurant(null)
      setActiveSidePanel('settings')
      if (auth.hasApiAuth && !userProfileState.hasLoaded && !userProfileState.isLoading) {
        void loadUserProfile()
      }
      return
    }
    openDetailPanel(restaurant)
  }

  function selectSearchResult(restaurant: Restaurant) {
    map.focusRestaurantOnMap(restaurant)
    setSelectedRestaurant(restaurant)
    setActiveSidePanel('restaurant')
  }

  function selectBookmarkedRestaurant(restaurant: Restaurant) {
    map.bookmarkFocusModeRef.current = true
    map.displayRestaurantsOnMap([restaurant], { preserveViewport: true })
    map.focusRestaurantOnMap(restaurant)
    setSelectedRestaurant(restaurant)
    setActiveSidePanel('restaurant')
  }

  async function submitRestaurantSearch(event?: FormEvent<HTMLFormElement>) {
    event?.preventDefault()
    const query = searchInput.trim()
    if (!query) {
      showToast('검색어를 입력해 주세요')
      return
    }

    const requestId = ++searchRequestIdRef.current
    const center = map.getSearchCenter()
    map.searchModeRef.current = true
    map.bookmarkFocusModeRef.current = false
    setSelectedRestaurant(null)
    setActiveSidePanel('search')
    setSearchQuery(query)
    setSearchResults([])
    setSearchErrorMessage('')
    setSearchState('loading')
    map.displayRestaurantsOnMap([])

    try {
      const restaurants = await fetchSearchRestaurants(query, center)
      if (searchRequestIdRef.current !== requestId) return
      setSearchResults(restaurants)
      setSearchState('loaded')
      map.displayRestaurantsOnMap(restaurants)
      map.fitMapToRestaurants(restaurants)
    } catch (error) {
      if (searchRequestIdRef.current !== requestId) return
      setSearchErrorMessage(
        error instanceof Error ? error.message : '검색 결과를 불러오지 못했습니다',
      )
      setSearchState('error')
      map.displayRestaurantsOnMap([])
    }
  }

  function clearRestaurantSearch() {
    map.searchModeRef.current = false
    map.bookmarkFocusModeRef.current = false
    setSearchInput('')
    setSearchQuery('')
    setSearchResults([])
    setSearchErrorMessage('')
    setSearchState('idle')
    setSelectedRestaurant(null)
    setActiveSidePanel('search')
    map.displayRestaurantsOnMap(map.viewportRestaurantsRef.current)
  }

  async function loadRecentAnalyses() {
    if (!auth.hasApiAuth) {
      setRecentAnalysesState({ data: { today: '', freeItems: [], expiredItems: [] }, isLoading: false, errorMessage: '', hasLoaded: true })
      return
    }

    setRecentAnalysesState((prev) => ({ ...prev, isLoading: true, errorMessage: '' }))

    try {
      const data = await fetchRecentAnalyses(auth.authHeaders)
      setRecentAnalysesState({ data, isLoading: false, errorMessage: '', hasLoaded: true })
    } catch (error) {
      setRecentAnalysesState((prev) => ({
        ...prev,
        isLoading: false,
        errorMessage: error instanceof Error ? error.message : '최근분석 목록을 불러오지 못했습니다',
        hasLoaded: true,
      }))
    }
  }

  function openRecentPanel() {
    const shouldOpen = activeSidePanel !== 'recent'
    setSelectedRestaurant(null)
    setActiveSidePanel(shouldOpen ? 'recent' : 'search')
    if (shouldOpen && !recentAnalysesState.hasLoaded && !recentAnalysesState.isLoading) {
      void loadRecentAnalyses()
    }
  }

  function openSettingsPanel() {
    const shouldOpen = activeSidePanel !== 'settings'
    setSelectedRestaurant(null)
    setActiveSidePanel(shouldOpen ? 'settings' : 'search')
    if (shouldOpen && auth.hasApiAuth && !userProfileState.hasLoaded && !userProfileState.isLoading) {
      void loadUserProfile()
    }
  }

  async function loadAiRecommendations(page: number, regionScope = aiRegionScope) {
    setAiRecommendState((prev) => ({ ...prev, page, isLoading: true, errorMessage: '' }))

    try {
      const params = new URLSearchParams({
        threshold: '0.1',
        page: page.toString(),
        pageSize: '10',
        regionScope,
      })
      if (map.currentPosition) {
        params.set('lat', map.currentPosition.latitude.toString())
        params.set('lng', map.currentPosition.longitude.toString())
      }

      const response = await fetch(`${BACKEND_BASE_URL}/api/ai-recommendations?${params.toString()}`)

      if (!response.ok) {
        throw new Error(`서버 응답 ${response.status}`)
      }

      const data = (await response.json()) as {
        items?: Record<string, unknown>[]
        page?: number | string
        hasNext?: boolean
        regionLabel?: string
        currentRegion?: { si?: string; gu?: string; dong?: string; label?: string } | null
        isRegionFiltered?: boolean
      }

      const items = (data.items ?? []).map(parseAiRecommendItem).filter((item) => item.id !== 0)

      setAiRecommendState({
        items,
        page: Number(data.page ?? page) || page,
        hasNext: data.hasNext === true,
        isLoading: false,
        errorMessage: '',
        hasLoaded: true,
        regionLabel: cleanText(data.regionLabel),
        currentRegionLabel: cleanText(data.currentRegion?.label),
        currentRegionSi: cleanText(data.currentRegion?.si),
        currentRegionGu: cleanText(data.currentRegion?.gu),
        currentRegionDong: cleanText(data.currentRegion?.dong),
        isRegionFiltered: data.isRegionFiltered === true,
      })
    } catch (error) {
      setAiRecommendState((prev) => ({
        ...prev,
        isLoading: false,
        errorMessage: error instanceof Error ? error.message : 'AI 추천 API 오류',
        hasLoaded: true,
      }))
    }
  }

  function openAiPanel() {
    setSelectedRestaurant(null)
    setActiveSidePanel((current) => {
      const next = current === 'ai' ? 'search' : 'ai'
      if (next === 'ai' && !aiRecommendState.hasLoaded) {
        loadAiRecommendations(1)
      }
      return next
    })
  }

  function changeAiRegionScope(regionScope: AiRegionScope) {
    setAiRegionScope(regionScope)
    if (activeSidePanel === 'ai') {
      loadAiRecommendations(1, regionScope)
    }
  }

  function focusRecentAnalysis(item: RecentAnalysisItem) {
    const restaurant = recentAnalysisToRestaurant(item)
    if (!restaurant) {
      showToast('최근분석 위치 정보를 찾지 못했습니다')
      return
    }
    map.focusRestaurantOnMap(restaurant)
    setSelectedRestaurant(restaurant)
    setActiveSidePanel('restaurant')
  }

  function focusAiRecommendation(item: AiRecommendItem) {
    const restaurant = aiRecommendToRestaurant(item)
    if (!restaurant) {
      showToast('위치 정보가 없는 추천입니다')
      return
    }
    map.focusRestaurantOnMap(restaurant)
    setSelectedRestaurant(restaurant)
    setActiveSidePanel('restaurant')
  }

  return (
    <>
      <main className="map-page">
        <section className="side-panel-column" aria-label="지도 사이드 패널">
          {!auth.isLoggedIn ? (
            <LoginPanel
              authStatus={auth.authStatus}
              authErrorMessage={auth.authErrorMessage}
              supabaseAvailable={Boolean(supabase)}
              onSignInWithGoogle={auth.signInWithGoogle}
              onSignInWithTestAccount={auth.signInWithTestAccount}
            />
          ) : (
            <>
              {activeSidePanel === 'search' && (
                <SearchPanel
                  searchInput={searchInput}
                  searchQuery={searchQuery}
                  searchResults={searchResults}
                  searchState={searchState}
                  searchErrorMessage={searchErrorMessage}
                  onSearchInputChange={(value) => {
                    setSearchInput(value)
                    if (!value.trim() && map.searchModeRef.current) {
                      clearRestaurantSearch()
                    }
                  }}
                  onSearchSubmit={submitRestaurantSearch}
                  onSelectResult={selectSearchResult}
                />
              )}
              {selectedRestaurant && activeSidePanel === 'restaurant' && (
                <RestaurantPanel
                  restaurant={selectedRestaurant}
                  bookmarkedStoreIds={bookmarks.bookmarkedStoreIds}
                  userProfile={userProfileState.profile}
                  onClose={() => { setSelectedRestaurant(null); setActiveSidePanel('search') }}
                  onCall={handleCall}
                  onToggleBookmark={bookmarks.toggleBookmark}
                  onRoute={handleRoute}
                  onShare={handleShare}
                  onDetailClick={handleDetailButtonClick}
                />
              )}
              {selectedRestaurant && activeSidePanel === 'detail' && (
                <DetailPanel
                  restaurant={selectedRestaurant}
                  bookmarkedStoreIds={bookmarks.bookmarkedStoreIds}
                  detailState={detail.detailState}
                  detailData={detail.detailData}
                  detailErrorMessage={detail.detailErrorMessage}
                  reviewSort={detail.reviewSort}
                  reviewPage={detail.reviewPage}
                  reviewTotalPages={detail.reviewTotalPages}
                  visibleDetailReviews={detail.visibleDetailReviews}
                  showReviewPageSkeleton={detail.showReviewPageSkeleton}
                  isReviewBatchLoading={detail.isReviewBatchLoading}
                  onBack={() => setActiveSidePanel('restaurant')}
                  onClose={() => { setSelectedRestaurant(null); setActiveSidePanel('search') }}
                  onCall={handleCall}
                  onToggleBookmark={bookmarks.toggleBookmark}
                  onRoute={handleRoute}
                  onShare={handleShare}
                  onRefresh={(restaurant) => openDetailPanel(restaurant, true)}
                  onChangeReviewSort={detail.changeReviewSort}
                  onChangeReviewPage={(page) => detail.changeReviewPage(page, selectedRestaurant)}
                  reviewActivityAvailable={reviewActivity.isAvailable}
                  getReviewLikeState={reviewActivity.getReviewLikeState}
                  getReviewReportState={reviewActivity.getReviewReportState}
                  onToggleReviewHeart={reviewActivity.toggleReviewHeart}
                  onSubmitReviewReport={reviewActivity.submitReviewReport}
                  onHideReview={detail.hideDetailReview}
                  onOpenReviewSource={reviewActivity.openReviewSource}
                  onShowToast={showToast}
                />
              )}
              {activeSidePanel === 'bookmarks' && (
                <BookmarkPanel
                  bookmarkedRestaurants={bookmarks.bookmarkedRestaurants}
                  onClose={() => setActiveSidePanel('search')}
                  onSelectRestaurant={selectBookmarkedRestaurant}
                  onToggleBookmark={bookmarks.toggleBookmark}
                />
              )}
              {activeSidePanel === 'recent' && (
                <RecentPanel
                  recentAnalysesState={recentAnalysesState}
                  hasApiAuth={auth.hasApiAuth}
                  onClose={() => setActiveSidePanel('search')}
                  onFocusItem={focusRecentAnalysis}
                  onRetry={loadRecentAnalyses}
                />
              )}
              {activeSidePanel === 'ai' && (
                <AiPanel
                  aiRecommendState={aiRecommendState}
                  aiRegionScope={aiRegionScope}
                  currentPositionExists={Boolean(map.currentPosition)}
                  onClose={() => setActiveSidePanel('search')}
                  onLoadPage={loadAiRecommendations}
                  onChangeRegionScope={changeAiRegionScope}
                  onFocusItem={focusAiRecommendation}
                />
              )}
              {activeSidePanel === 'settings' && (
                <SettingsPanel
                  userProfileState={userProfileState}
                  onClose={() => setActiveSidePanel('search')}
                  onTogglePremium={toggleUserPremium}
                  onChargeCoins={chargeCoins}
                  onSignOut={auth.signOut}
                  onRetryLoadProfile={loadUserProfile}
                  reviewActivityAvailable={reviewActivity.isAvailable}
                  likedReviewsState={reviewActivity.likedReviewsState}
                  recentReviewsState={reviewActivity.recentReviewsState}
                  onLoadLikedReviews={reviewActivity.loadLikedReviews}
                  onLoadRecentReviews={reviewActivity.loadRecentReviews}
                  onOpenLikedReview={reviewActivity.openReviewSource}
                  onOpenRecentReview={reviewActivity.openRecentReviewSource}
                  onRemoveLikedReview={reviewActivity.removeLikedReview}
                  onRemoveRecentReview={reviewActivity.removeRecentReview}
                  onClearRecentReviews={reviewActivity.clearRecentReviews}
                />
              )}
            </>
          )}
        </section>

        <section className="map-view" aria-label="지도">
          <div ref={map.mapContainerRef} className="map-container" />
          {map.loadState === 'loading' && (
            <div className="map-status">카카오맵을 불러오는 중입니다</div>
          )}
          {map.loadState === 'error' && (
            <div className="map-status map-status-error">{map.errorMessage}</div>
          )}
          {map.loadState === 'ready' && map.placesErrorMessage && (
            <div className="map-status map-status-error">{map.placesErrorMessage}</div>
          )}
          {auth.isLoggedIn && (
            <MapUsageBadge
              profile={userProfileState.profile}
              isLoading={userProfileState.isLoading}
            />
          )}
          <nav className="map-tool-rail" aria-label="지도 메뉴">
            <div className="map-tool-brand" aria-hidden="true">
              <img src={appLogoUrl} alt="" />
            </div>
            <button
              type="button"
              className="map-tool-button"
              aria-label="장소 검색"
              onClick={() => { setSelectedRestaurant(null); setActiveSidePanel('search') }}
            >
              <Search aria-hidden="true" size={20} strokeWidth={2.2} />
            </button>
            <button
              type="button"
              className="map-tool-button"
              aria-label="내 위치로 이동"
              onClick={map.focusCurrentLocationOnMap}
            >
              <LocateFixed aria-hidden="true" size={20} strokeWidth={2.2} />
            </button>
            <button
              type="button"
              className="map-tool-button"
              aria-label="북마크"
              onClick={() => {
                setSelectedRestaurant(null)
                setActiveSidePanel((current) => current === 'bookmarks' ? 'search' : 'bookmarks')
              }}
            >
              <Bookmark aria-hidden="true" size={20} strokeWidth={2.2} />
            </button>
            <button
              type="button"
              className="map-tool-button"
              aria-label="최근분석"
              onClick={openRecentPanel}
            >
              <Clock aria-hidden="true" size={20} strokeWidth={2.2} />
            </button>
            <button
              type="button"
              className="map-tool-button"
              aria-label="AI 추천"
              onClick={openAiPanel}
            >
              <Sparkles aria-hidden="true" size={20} strokeWidth={2.2} />
            </button>
            <button
              type="button"
              className="map-tool-button"
              aria-label="설정"
              onClick={openSettingsPanel}
            >
              <Settings aria-hidden="true" size={20} strokeWidth={2.2} />
            </button>
          </nav>
          {toastMessage && <div className="map-toast">{toastMessage}</div>}
        </section>
      </main>
      {showIntroSplash && <IntroSplash />}
    </>
  )
}

function IntroSplash() {
  return (
    <section className="intro-splash" aria-label="진실의 입 시작 화면">
      <div className="intro-splash-track" aria-hidden="true">
        <div className="intro-splash-runner">
          <span className="intro-splash-car intro-splash-logo-car">
            <img className="intro-splash-logo" src={appLogoUrl} alt="" />
          </span>
          <span className="intro-splash-car intro-splash-letter">진</span>
          <span className="intro-splash-car intro-splash-letter">실</span>
          <span className="intro-splash-car intro-splash-letter">의</span>
          <span className="intro-splash-car intro-splash-letter">입</span>
        </div>
      </div>
    </section>
  )
}

function MapUsageBadge({
  profile,
  isLoading,
}: {
  profile: UserProfile | null
  isLoading: boolean
}) {
  const loading = isLoading && !profile

  return (
    <div className="map-usage-badge" aria-label="분석 잔여 횟수">
      <MapUsageBadgeItem
        icon={<Coins aria-hidden="true" size={15} strokeWidth={2.2} />}
        label="코인"
        value={loading ? '-' : (profile?.coin ?? 0).toLocaleString()}
      />
      <MapUsageBadgeItem
        icon={<Zap aria-hidden="true" size={15} strokeWidth={2.2} />}
        label="무료분석"
        value={loading ? '-' : (profile?.freecount ?? 0).toLocaleString()}
      />
      <MapUsageBadgeItem
        icon={<Crown aria-hidden="true" size={15} strokeWidth={2.2} />}
        label="추가분석"
        value={loading ? '-' : (profile?.premiumcount ?? 0).toLocaleString()}
      />
    </div>
  )
}

function MapUsageBadgeItem({
  icon,
  label,
  value,
}: {
  icon: ReactNode
  label: string
  value: string
}) {
  return (
    <span className="map-usage-item">
      {icon}
      <span>{label}</span>
      <strong>{value}</strong>
    </span>
  )
}

export default App
