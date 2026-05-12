import { Bookmark, BookmarkCheck, X } from 'lucide-react'
import { RestaurantThumb } from '../RestaurantThumb'
import { getRestaurantStoreId, type Restaurant } from '../../lib/restaurant'

type Props = {
  bookmarkedRestaurants: Restaurant[]
  onClose: () => void
  onSelectRestaurant: (restaurant: Restaurant) => void
  onToggleBookmark: (restaurant: Restaurant) => void
}

export function BookmarkPanel({
  bookmarkedRestaurants,
  onClose,
  onSelectRestaurant,
  onToggleBookmark,
}: Props) {
  return (
    <aside className="restaurant-panel bookmark-panel" aria-label="북마크">
      <button
        type="button"
        className="panel-close-button"
        aria-label="북마크 닫기"
        onClick={onClose}
      >
        <X aria-hidden="true" size={19} strokeWidth={2.2} />
      </button>

      <section className="bookmark-panel-body">
        <div className="bookmark-panel-header">
          <BookmarkCheck aria-hidden="true" size={22} strokeWidth={2.2} />
          <div>
            <p>Saved Places</p>
            <h2>북마크</h2>
          </div>
        </div>

        {bookmarkedRestaurants.length === 0 ? (
          <div className="bookmark-empty">아직 북마크한 가게가 없습니다</div>
        ) : (
          <ul className="bookmark-list">
            {bookmarkedRestaurants.map((restaurant) => (
              <li key={getRestaurantStoreId(restaurant)}>
                <button
                  type="button"
                  className="bookmark-list-item"
                  onClick={() => onSelectRestaurant(restaurant)}
                >
                  <RestaurantThumb restaurant={restaurant} className="bookmark-thumb" />
                  <span className="bookmark-copy">
                    <strong>{restaurant.name}</strong>
                    <small>
                      {restaurant.category} · {restaurant.address || '주소 정보 없음'}
                    </small>
                  </span>
                </button>
                <button
                  type="button"
                  className="bookmark-remove-button"
                  aria-label={`${restaurant.name} 북마크 해제`}
                  onClick={(event) => {
                    event.stopPropagation()
                    onToggleBookmark(restaurant)
                  }}
                >
                  <BookmarkCheck aria-hidden="true" size={18} strokeWidth={2.2} />
                </button>
              </li>
            ))}
          </ul>
        )}
      </section>
    </aside>
  )
}
