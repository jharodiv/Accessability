import 'package:AccessAbility/accessability/firebaseServices/models/place.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:AccessAbility/accessability/logic/bloc/user/user_event.dart';
import 'package:AccessAbility/accessability/logic/bloc/user/user_state.dart';
import 'package:AccessAbility/accessability/data/repositories/user_repository.dart';

class UserBloc extends Bloc<UserEvent, UserState> {
  final UserRepository userRepository;

  UserBloc({required this.userRepository}) : super(UserInitial()) {
    on<FetchUserData>(_onFetchUserData);
    on<UploadProfilePictureEvent>(_onUploadProfilePictureEvent);
    on<AddPlaceEvent>(_onAddPlaceEvent); // Register AddPlaceEvent handler
    on<GetPlacesByCategoryEvent>(_onGetPlacesByCategoryEvent); // if needed
    on<DeletePlaceEvent>(_onDeletePlaceEvent); // if needed
  }

  Future<void> _onFetchUserData(
      FetchUserData event, Emitter<UserState> emit) async {
    emit(UserLoading());
    try {
      final user = await userRepository.getCachedUser();
      if (user != null) {
        emit(UserLoaded(user));
      } else {
        emit(UserError('No user data available'));
      }
    } catch (e) {
      emit(UserError('Failed to fetch user data: ${e.toString()}'));
    }
  }

  Future<void> _onUploadProfilePictureEvent(
    UploadProfilePictureEvent event,
    Emitter<UserState> emit,
  ) async {
    emit(UserLoading());
    try {
      final updatedUser = await userRepository.updateProfilePicture(
        event.uid,
        event.profilePicture,
      );
      emit(UserLoaded(updatedUser));
    } catch (e) {
      emit(UserError('Failed to update profile picture: ${e.toString()}'));
    }
  }

  Future<void> _onAddPlaceEvent(
      AddPlaceEvent event, Emitter<UserState> emit) async {
    emit(PlaceOperationLoading());
    try {
      await userRepository.addPlace(
        event.name,
        event.category,
        event.latitude,
        event.longitude,
      );
      emit(PlaceOperationSuccess());
    } catch (e) {
      emit(PlaceOperationError('Failed to add place: ${e.toString()}'));
    }
  }

  Future<void> _onGetPlacesByCategoryEvent(
      GetPlacesByCategoryEvent event, Emitter<UserState> emit) async {
    emit(PlaceOperationLoading());
    try {
      await emit.forEach<List<Place>>(
        userRepository.getPlacesByCategory(event.category),
        onData: (places) => PlacesLoaded(places),
        onError: (error, stackTrace) =>
            PlaceOperationError('Failed to load places: ${error.toString()}'),
      );
    } catch (e) {
      emit(PlaceOperationError('Failed to get places: ${e.toString()}'));
    }
  }

  Future<void> _onDeletePlaceEvent(
      DeletePlaceEvent event, Emitter<UserState> emit) async {
    emit(PlaceOperationLoading());
    try {
      await userRepository.deletePlace(event.placeId);
      emit(PlaceOperationSuccess());
    } catch (e) {
      emit(PlaceOperationError('Failed to delete place: ${e.toString()}'));
    }
  }
}
