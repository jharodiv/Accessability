import 'package:accessability/accessability/logic/bloc/place/bloc/place_bloc.dart';
import 'package:accessability/accessability/logic/bloc/place/bloc/place_event.dart';
import 'package:accessability/accessability/logic/bloc/place/bloc/place_state.dart';
import 'package:accessability/accessability/logic/bloc/user/user_bloc.dart';
import 'package:accessability/accessability/logic/bloc/user/user_state.dart'
    hide PlaceOperationLoading, PlacesLoaded, PlaceOperationError;
import 'package:accessability/accessability/presentation/widgets/shimmer/shimmer_place.dart';
import 'package:accessability/accessability/data/model/place.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:easy_localization/easy_localization.dart';

class AddPlaceWidget extends StatefulWidget {
  // Optional callback for showing the place on the map.
  final void Function(Place)? onShowPlace;

  const AddPlaceWidget({Key? key, this.onShowPlace}) : super(key: key);

  @override
  _AddPlaceWidgetState createState() => _AddPlaceWidgetState();
}

class _AddPlaceWidgetState extends State<AddPlaceWidget> {
  @override
  void initState() {
    super.initState();
    // Fetch all places when this widget is initialized.
    context.read<PlaceBloc>().add(const GetAllPlacesEvent());
  }

  // Navigate to the /addPlace screen.
  Future<void> _navigateToAddNewPlace() async {
    await Navigator.pushNamed(context, '/addPlace');
    // After returning, re-fetch all places.
    context.read<PlaceBloc>().add(const GetAllPlacesEvent());
  }

  // Dispatch a DeletePlaceEvent to remove a place from Firestore.
  void _removePlace(String placeId) {
    context.read<PlaceBloc>().add(DeletePlaceEvent(placeId: placeId));
  }

  // NEW: Toggle home status for a place
  void _toggleHomePlace(String placeId, bool currentHomeStatus) {
    context.read<PlaceBloc>().add(
          SetHomePlaceEvent(
            placeId: placeId,
            isHome: !currentHomeStatus,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize:
          MainAxisSize.min, // Let the column shrink to fit its children
      children: [
        // "Add a new Place" tile.
        ListTile(
          leading: const CircleAvatar(
            backgroundColor: Color(0xFF6750A4),
            child: Icon(Icons.add, color: Colors.white),
          ),
          title: Text(
            'addNewPlace'.tr(),
            style: const TextStyle(
              color: Color(0xFF6750A4),
              fontWeight: FontWeight.bold,
              fontSize: 16.0,
            ),
          ),
          onTap: _navigateToAddNewPlace,
        ),
        const Divider(),

        // The list of places.
        Flexible(
          fit: FlexFit.loose,
          child: BlocBuilder<PlaceBloc, PlaceState>(
            builder: (context, state) {
              if (state is PlaceOperationLoading) {
                return const Center(child: ShimmerPlaceWidget());
              } else if (state is PlacesLoaded) {
                final List<Place> places = state.places;
                if (places.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 30),
                    child: Center(child: Text('noPlacesFound'.tr())),
                  );
                }
                return ListView.builder(
                  shrinkWrap: true, // Prevents large empty space.
                  padding: EdgeInsets.zero, // Removes default list padding.
                  itemCount: places.length,
                  itemBuilder: (context, index) {
                    final place = places[index];
                    return Column(
                      children: [
                        ListTile(
                          // Tapping on the tile (icon or text) will print and trigger the callback.
                          onTap: () {
                            print("Place tapped: ${place.name}");
                            widget.onShowPlace?.call(place);
                          },
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: place.isHome
                                    ? Colors.orange // Highlight home places
                                    : const Color(0xFF6750A4),
                              ),
                            ),
                            child: Center(
                              child: Icon(
                                place.isHome
                                    ? Icons.home
                                    : Icons.place, // Home icon for home places
                                color: place.isHome
                                    ? Colors.orange
                                    : const Color(0xFF6750A4),
                              ),
                            ),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  place.isHome
                                      ? _getHomeDisplayName(place, context)
                                      : place.name,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: place.isHome
                                        ? Colors.orange
                                        : Colors.black,
                                  ),
                                ),
                              ),
                              if (place.isHome)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: Colors.orange.withOpacity(0.3)),
                                  ),
                                  child: Text(
                                    'home'.tr(),
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.orange,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          // "x" button remains only for removal.
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Home toggle button
                              IconButton(
                                icon: Icon(
                                  place.isHome
                                      ? Icons.home
                                      : Icons.home_outlined,
                                  color: place.isHome
                                      ? Colors.orange
                                      : Colors.grey,
                                ),
                                onPressed: () =>
                                    _toggleHomePlace(place.id, place.isHome),
                              ),
                              // Delete button
                              IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () => _removePlace(place.id),
                              ),
                            ],
                          ),
                        ),
                        // Small divider between items.
                        if (index < places.length - 1)
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16.0),
                            child: Divider(height: 1, thickness: 0.8),
                          ),
                      ],
                    );
                  },
                );
              } else if (state is PlaceOperationError) {
                return Center(
                  child: Text(
                    "errorMessage".tr(args: [state.message]),
                  ),
                );
              } else {
                // For states like PlaceInitial or any unhandled states.
                return const SizedBox.shrink();
              }
            },
          ),
        ),
      ],
    );
  }

  // NEW: Get display name for home places
  String _getHomeDisplayName(Place place, BuildContext context) {
    final userState = context.read<UserBloc>().state;
    if (userState is UserLoaded) {
      final username = [userState.user.firstName, userState.user.lastName]
          .where((s) => s != null && s!.trim().isNotEmpty)
          .join(' ')
          .trim();

      if (username.isNotEmpty) {
        return "$username's Home";
      } else {
        return "${userState.user.username}'s Home";
      }
    }
    return "My Home";
  }
}
