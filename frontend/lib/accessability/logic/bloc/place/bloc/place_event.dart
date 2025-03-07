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
  final String? category; // Optional category

  const AddPlaceEvent({
    required this.name,
    required this.latitude,
    required this.longitude,
    this.category,
  });

  @override
  List<Object?> get props => [name, latitude, longitude];
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
