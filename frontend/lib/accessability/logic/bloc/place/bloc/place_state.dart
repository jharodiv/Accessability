import 'package:AccessAbility/accessability/data/model/place.dart';
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
