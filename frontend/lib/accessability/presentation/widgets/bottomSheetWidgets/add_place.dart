import 'package:AccessAbility/accessability/logic/bloc/place/bloc/place_bloc.dart';
import 'package:AccessAbility/accessability/logic/bloc/place/bloc/place_event.dart';
import 'package:AccessAbility/accessability/logic/bloc/place/bloc/place_state.dart';
import 'package:AccessAbility/accessability/presentation/widgets/shimmer/shimmer_place.dart';
import 'package:AccessAbility/accessability/firebaseServices/models/place.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
          title: const Text(
            "Add a new Place",
            style: TextStyle(
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
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 30),
                    child: Center(child: Text("No places found.")),
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
                                color: const Color(0xFF6750A4),
                              ),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.place,
                                color: Color(0xFF6750A4),
                              ),
                            ),
                          ),
                          title: Text(
                            place.name,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          // "x" button remains only for removal.
                          trailing: IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => _removePlace(place.id),
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
                return Center(child: Text("Error: ${state.message}"));
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
}
