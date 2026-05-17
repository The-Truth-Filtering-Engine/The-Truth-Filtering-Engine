import '../map/models/restaurant_model.dart';

enum FriendMessageType {
  restaurantCard,
  appointment,
}

class TruthFriend {
  const TruthFriend({
    required this.id,
    required this.displayName,
    required this.addedAt,
    this.handle,
    this.avatarText,
  });

  final String id;
  final String displayName;
  final DateTime addedAt;
  final String? handle;
  final String? avatarText;

  TruthFriend copyWith({
    String? displayName,
    DateTime? addedAt,
    String? handle,
    String? avatarText,
  }) {
    return TruthFriend(
      id: id,
      displayName: displayName ?? this.displayName,
      addedAt: addedAt ?? this.addedAt,
      handle: handle ?? this.handle,
      avatarText: avatarText ?? this.avatarText,
    );
  }
}

class RestaurantCardPayload {
  const RestaurantCardPayload({
    required this.storeId,
    required this.name,
    required this.category,
    required this.address,
    required this.reviewSummary,
    required this.truthScore,
    required this.latitude,
    required this.longitude,
    this.placeUrl,
    this.imageUrl,
  });

  final String storeId;
  final String name;
  final String category;
  final String address;
  final String reviewSummary;
  final int truthScore;
  final double latitude;
  final double longitude;
  final String? placeUrl;
  final String? imageUrl;

  factory RestaurantCardPayload.fromRestaurant(RestaurantModel restaurant) {
    return RestaurantCardPayload(
      storeId: restaurant.effectiveStoreId,
      name: restaurant.name,
      category: restaurant.category,
      address: restaurant.address,
      reviewSummary: restaurant.reviewSummary,
      truthScore: restaurant.truthScore,
      latitude: restaurant.latitude,
      longitude: restaurant.longitude,
      placeUrl: restaurant.placeUrl,
      imageUrl: restaurant.imageUrl,
    );
  }

  RestaurantModel toRestaurantModel() {
    return RestaurantModel(
      id: storeId,
      storeId: storeId,
      name: name,
      address: address,
      category: category,
      truthScore: truthScore,
      reviewSummary: reviewSummary,
      latitude: latitude,
      longitude: longitude,
      placeUrl: placeUrl,
      imageUrl: imageUrl,
    );
  }
}

class FriendMessage {
  const FriendMessage({
    required this.id,
    required this.friendId,
    required this.senderName,
    required this.type,
    required this.restaurant,
    required this.sentAt,
    this.note,
    this.appointmentTime,
    this.isRead = false,
  });

  final String id;
  final String friendId;
  final String senderName;
  final FriendMessageType type;
  final RestaurantCardPayload restaurant;
  final DateTime sentAt;
  final String? note;
  final DateTime? appointmentTime;
  final bool isRead;

  DateTime? get reminderTime {
    final appointment = appointmentTime;
    if (appointment == null) return null;
    return appointment.subtract(const Duration(hours: 2));
  }

  FriendMessage copyWith({
    String? senderName,
    FriendMessageType? type,
    RestaurantCardPayload? restaurant,
    DateTime? sentAt,
    String? note,
    DateTime? appointmentTime,
    bool? isRead,
  }) {
    return FriendMessage(
      id: id,
      friendId: friendId,
      senderName: senderName ?? this.senderName,
      type: type ?? this.type,
      restaurant: restaurant ?? this.restaurant,
      sentAt: sentAt ?? this.sentAt,
      note: note ?? this.note,
      appointmentTime: appointmentTime ?? this.appointmentTime,
      isRead: isRead ?? this.isRead,
    );
  }
}

class FriendMessageDraft {
  const FriendMessageDraft({
    required this.friendId,
    required this.restaurant,
    this.note,
    this.appointmentTime,
  });

  final String friendId;
  final RestaurantCardPayload restaurant;
  final String? note;
  final DateTime? appointmentTime;
}
