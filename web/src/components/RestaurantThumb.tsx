import { type Restaurant, restaurantThumbnailSrc } from '../lib/restaurant'

const CATEGORY_THUMBNAIL_BASE = '/images/thumbnails'

type Props = {
  restaurant: Pick<Restaurant, 'category' | 'categoryName' | 'categoryGroupName' | 'imageUrl'>
  className?: string
}

export function RestaurantThumb({ restaurant, className = '' }: Props) {
  return (
    <img
      className={['restaurant-card-image', className].filter(Boolean).join(' ')}
      src={restaurantThumbnailSrc(restaurant)}
      alt=""
      aria-hidden="true"
      loading="lazy"
      draggable={false}
      onError={(event) => {
        if (!event.currentTarget.src.includes('/images/thumbnails/default.png')) {
          event.currentTarget.src = `${CATEGORY_THUMBNAIL_BASE}/default.png`
        }
      }}
    />
  )
}
