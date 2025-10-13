import 'package:accessability/accessability/data/model/place.dart';
import 'package:equatable/equatable.dart';

abstract class PlaceEvent extends Equatable {
  const PlaceEvent();

  @override
  List<Object?> get props => [];
}

class AddPlaceEvent extends PlaceEvent {
  final String name;
  final double latitude;
  final double longitude;
  final String? category;
  final double notificationRadius; // NEW

  const AddPlaceEvent({
    required this.name,
    required this.latitude,
    required this.longitude,
    this.category,
    this.notificationRadius = 100.0, // NEW
  });

  @override
  List<Object?> get props => [name, latitude, longitude, notificationRadius];
}

class GetAllPlacesEvent extends PlaceEvent {
  const GetAllPlacesEvent();
}

class GetPlacesByCategoryEvent extends PlaceEvent {
  final String category;

  const GetPlacesByCategoryEvent({required this.category});

  @override
  List<Object?> get props => [category];
}

class DeletePlaceEvent extends PlaceEvent {
  final String placeId;

  const DeletePlaceEvent({required this.placeId});

  @override
  List<Object?> get props => [placeId];
}

class UpdatePlaceCategoryEvent extends PlaceEvent {
  final String placeId;
  final String newCategory;

  const UpdatePlaceCategoryEvent(
      {required this.placeId, required this.newCategory});
}

class RemovePlaceFromCategoryEvent extends PlaceEvent {
  final String placeId;

  const RemovePlaceFromCategoryEvent({required this.placeId});
}

class UpdatePlaceNotificationRadiusEvent extends PlaceEvent {
  final String placeId;
  final double radius;

  const UpdatePlaceNotificationRadiusEvent({
    required this.placeId,
    required this.radius,
  });

  @override
  List<Object?> get props => [placeId, radius];
}

class ToggleFavoritePlaceEvent extends PlaceEvent {
  final Place place;

  const ToggleFavoritePlaceEvent({required this.place});

  @override
  List<Object> get props => [place];
}

class CheckFavoriteStatusEvent extends PlaceEvent {
  final Place place;

  const CheckFavoriteStatusEvent({required this.place});

  @override
  List<Object> get props => [place];
}

class GetFavoritePlacesEvent extends PlaceEvent {
  const GetFavoritePlacesEvent();

  @override
  List<Object> get props => [];
}

class AddToFavoritesEvent extends PlaceEvent {
  final Place place;

  const AddToFavoritesEvent({required this.place});

  @override
  List<Object> get props => [place];
}

class DeletePlaceCompletelyEvent extends PlaceEvent {
  final String placeId;

  const DeletePlaceCompletelyEvent({required this.placeId});

  @override
  List<Object> get props => [placeId];
}

class ToggleFavoriteWithDeletionEvent extends PlaceEvent {
  final Place place;

  const ToggleFavoriteWithDeletionEvent({required this.place});

  @override
  List<Object> get props => [place];
}

class CleanupOrphanedPlacesEvent extends PlaceEvent {
  const CleanupOrphanedPlacesEvent();

  @override
  List<Object> get props => [];
}
