import 'package:accessability/accessability/data/model/place.dart';
import 'package:equatable/equatable.dart';

abstract class PlaceState extends Equatable {
  const PlaceState();

  @override
  List<Object?> get props => [];
}

class PlaceInitial extends PlaceState {}

class PlaceOperationLoading extends PlaceState {}

class PlaceOperationSuccess extends PlaceState {}

class PlacesLoaded extends PlaceState {
  final List<Place> places;

  const PlacesLoaded(this.places);

  @override
  List<Object?> get props => [places];
}

class PlaceOperationError extends PlaceState {
  final String message;

  const PlaceOperationError(this.message);

  @override
  List<Object?> get props => [message];
}

// NEW: Add these missing state classes
class PlaceFavoriteStatusChecked extends PlaceState {
  final bool isFavorite;

  const PlaceFavoriteStatusChecked({required this.isFavorite});

  @override
  List<Object?> get props => [isFavorite];
}

class PlaceFavoriteToggled extends PlaceState {
  final Place place;
  final bool isFavorite;

  const PlaceFavoriteToggled({required this.place, required this.isFavorite});

  @override
  List<Object?> get props => [place, isFavorite];
}

class UserHomeLoaded extends PlaceState {
  final Place? homePlace;

  const UserHomeLoaded(this.homePlace);

  @override
  List<Object?> get props => [homePlace];
}
