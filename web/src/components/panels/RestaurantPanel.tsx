import {
  Bookmark,
  BookmarkCheck,
  Info,
  MapPin,
  Navigation,
  Phone,
  Share2,
  X,
} from 'lucide-react'
import { RestaurantThumb } from '../RestaurantThumb'
import { formatDistance } from '../../lib/format'
import { getRestaurantStoreId, type Restaurant } from '../../lib/restaurant'
import { getDetailUsageInfo } from '../../lib/detailUsage'
import { type UserProfile } from '../../api/user'

type Props = {
  restaurant: Restaurant
  bookmarkedStoreIds: string[]
  userProfile: UserProfile | null
  onClose: () => void
  onCall: (restaurant: Restaurant) => void
  onToggleBookmark: (restaurant: Restaurant) => void
  onRoute: (restaurant: Restaurant) => void
  onShare: (restaurant: Restaurant) => void
  onDetailClick: (restaurant: Restaurant) => void
}

export function RestaurantPanel({
  restaurant,
  bookmarkedStoreIds,
  userProfile,
  onClose,
  onCall,
  onToggleBookmark,
  onRoute,
  onShare,
  onDetailClick,
}: Props) {
  const isBookmarked = bookmarkedStoreIds.includes(getRestaurantStoreId(restaurant))
  const usageInfo = getDetailUsageInfo(restaurant, userProfile)

  return (
    <aside className="restaurant-panel" aria-label="선택한 가게 정보">
      <button
        type="button"
        className="panel-close-button"
        aria-label="가게 정보 닫기"
        onClick={onClose}
      >
        <X aria-hidden="true" size={19} strokeWidth={2.2} />
      </button>

      <div className="restaurant-panel-hero">
        <RestaurantThumb restaurant={restaurant} className="restaurant-thumbnail" />
      </div>

      <section className="restaurant-panel-body">
        <p className="restaurant-category">{restaurant.category}</p>
        <h2>{restaurant.name}</h2>
        <p className="restaurant-meta">
          <MapPin aria-hidden="true" size={15} strokeWidth={2.1} />
          <span>
            {restaurant.address || '주소 정보 없음'} ·{' '}
            {formatDistance(restaurant.distance)}
          </span>
        </p>

        <div className="restaurant-actions" aria-label="가게 액션">
          <button type="button" onClick={() => onCall(restaurant)}>
            <Phone aria-hidden="true" size={20} strokeWidth={2.1} />
            <span>Call</span>
          </button>
          <button type="button" onClick={() => onToggleBookmark(restaurant)}>
            {isBookmarked ? (
              <BookmarkCheck aria-hidden="true" size={20} strokeWidth={2.1} />
            ) : (
              <Bookmark aria-hidden="true" size={20} strokeWidth={2.1} />
            )}
            <span>Save</span>
          </button>
          <button type="button" onClick={() => onRoute(restaurant)}>
            <Navigation aria-hidden="true" size={20} strokeWidth={2.1} />
            <span>Route</span>
          </button>
          <button type="button" onClick={() => onShare(restaurant)}>
            <Share2 aria-hidden="true" size={20} strokeWidth={2.1} />
            <span>Share</span>
          </button>
        </div>

        <button
          type="button"
          className="detail-button"
          onClick={() => onDetailClick(restaurant)}
        >
          <Info aria-hidden="true" size={18} strokeWidth={2.2} />
          {usageInfo.label}
        </button>
      </section>
    </aside>
  )
}
