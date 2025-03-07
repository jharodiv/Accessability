import 'package:AccessAbility/accessability/logic/bloc/place/bloc/place_event.dart';
import 'package:AccessAbility/accessability/logic/bloc/place/bloc/place_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:AccessAbility/accessability/firebaseServices/models/place.dart';
import 'package:AccessAbility/accessability/data/repositories/place_repository.dart';

class PlaceBloc extends Bloc<PlaceEvent, PlaceState> {
  final PlaceRepository placeRepository;

  PlaceBloc({required this.placeRepository}) : super(PlaceInitial()) {
    on<AddPlaceEvent>(_onAddPlaceEvent);
    on<GetAllPlacesEvent>(_onGetAllPlacesEvent);
    on<GetPlacesByCategoryEvent>(_onGetPlacesByCategoryEvent);
    on<DeletePlaceEvent>(_onDeletePlaceEvent);
    on<UpdatePlaceCategoryEvent>(_onUpdatePlaceCategoryEvent);
    on<RemovePlaceFromCategoryEvent>(_onRemovePlaceFromCategoryEvent);
  }

  Future<void> _onAddPlaceEvent(
      AddPlaceEvent event, Emitter<PlaceState> emit) async {
    emit(PlaceOperationLoading());
    try {
      await placeRepository.addPlace(
        event.name,
        event.latitude,
        event.longitude,
        category: event.category, // Optional category passed if available.
      );
      emit(PlaceOperationSuccess());
    } catch (e) {
      emit(PlaceOperationError('Failed to add place: ${e.toString()}'));
    }
  }

  Future<void> _onGetAllPlacesEvent(
      GetAllPlacesEvent event, Emitter<PlaceState> emit) async {
    emit(PlaceOperationLoading());
    try {
      final places = await placeRepository.getAllPlaces();
      emit(PlacesLoaded(places));
    } catch (e) {
      emit(PlaceOperationError('Failed to load all places: ${e.toString()}'));
    }
  }

  Future<void> _onGetPlacesByCategoryEvent(
      GetPlacesByCategoryEvent event, Emitter<PlaceState> emit) async {
    emit(PlaceOperationLoading());
    try {
      await emit.forEach<List<Place>>(
        placeRepository.getPlacesByCategory(event.category),
        onData: (places) => PlacesLoaded(places),
        onError: (error, stackTrace) =>
            PlaceOperationError('Failed to load places: ${error.toString()}'),
      );
    } catch (e) {
      emit(PlaceOperationError('Failed to get places: ${e.toString()}'));
    }
  }

  Future<void> _onDeletePlaceEvent(
      DeletePlaceEvent event, Emitter<PlaceState> emit) async {
    emit(PlaceOperationLoading());
    try {
      await placeRepository.deletePlace(event.placeId);
      emit(PlaceOperationSuccess());
    } catch (e) {
      emit(PlaceOperationError('Failed to delete place: ${e.toString()}'));
    }
  }

  Future<void> _onUpdatePlaceCategoryEvent(
      UpdatePlaceCategoryEvent event, Emitter<PlaceState> emit) async {
    emit(PlaceOperationLoading());
    try {
      await placeRepository.updatePlaceCategory(
          event.placeId, event.newCategory);
      emit(PlaceOperationSuccess());
    } catch (e) {
      emit(PlaceOperationError(
          'Failed to update place category: ${e.toString()}'));
    }
  }

  Future<void> _onRemovePlaceFromCategoryEvent(
      RemovePlaceFromCategoryEvent event, Emitter<PlaceState> emit) async {
    emit(PlaceOperationLoading());
    try {
      await placeRepository.removePlaceFromCategory(event.placeId);
      emit(PlaceOperationSuccess());
    } catch (e) {
      emit(PlaceOperationError(
          'Failed to remove place from category: ${e.toString()}'));
    }
  }
}
