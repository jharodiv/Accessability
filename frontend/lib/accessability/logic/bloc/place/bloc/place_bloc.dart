import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:AccessAbility/accessability/firebaseServices/models/place.dart';
import 'place_event.dart';
import 'place_state.dart';
import 'package:AccessAbility/accessability/data/repositories/place_repository.dart';

class PlaceBloc extends Bloc<PlaceEvent, PlaceState> {
  final PlaceRepository placeRepository;

  PlaceBloc({required this.placeRepository}) : super(PlaceInitial()) {
    on<AddPlaceEvent>(_onAddPlaceEvent);
    on<GetAllPlacesEvent>(_onGetAllPlacesEvent);
    on<GetPlacesByCategoryEvent>(_onGetPlacesByCategoryEvent);
    on<DeletePlaceEvent>(_onDeletePlaceEvent);
  }

  Future<void> _onAddPlaceEvent(
      AddPlaceEvent event, Emitter<PlaceState> emit) async {
    emit(PlaceOperationLoading());
    try {
      await placeRepository.addPlace(
          event.name, event.latitude, event.longitude);
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
}
