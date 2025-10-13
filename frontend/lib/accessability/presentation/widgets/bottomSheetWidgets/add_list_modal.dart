import 'package:accessability/accessability/data/model/place.dart';
import 'package:accessability/accessability/logic/bloc/place/bloc/place_bloc.dart';
import 'package:accessability/accessability/logic/bloc/place/bloc/place_state.dart';
import 'package:accessability/accessability/themes/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';

class AddListModal extends StatefulWidget {
  const AddListModal({super.key});

  @override
  _AddListModalState createState() => _AddListModalState();
}

class _AddListModalState extends State<AddListModal> {
  String? selectedCategory;
  final List<Place> selectedPlaces = [];
  final primaryColor = const Color(0xFF6750A4);

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

    final Color bgColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final Color textColor = isDarkMode ? Colors.white : Colors.black87;
    final Color subtitleColor = isDarkMode ? Colors.white70 : Colors.black54;
    final Color borderColor =
        isDarkMode ? Colors.white24 : primaryColor.withOpacity(0.3);

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: isDarkMode
                  ? Colors.black.withOpacity(0.6)
                  : Colors.black.withOpacity(0.15),
              blurRadius: 12,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Wrap(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? Colors.white24
                            : primaryColor.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Title
                  Center(
                    child: Text(
                      "create_new_list".tr(),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Category Dropdown
                  DropdownButtonFormField<String>(
                    dropdownColor:
                        isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
                    decoration: InputDecoration(
                      labelText: "select_category".tr(),
                      labelStyle: TextStyle(
                        color: isDarkMode ? Colors.white70 : primaryColor,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: borderColor),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: primaryColor, width: 2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    style: TextStyle(color: textColor),
                    value: selectedCategory,
                    onChanged: (value) {
                      setState(() => selectedCategory = value);
                    },
                    items: <String>["favorites", "want_to_go", "visited"]
                        .map((category) => DropdownMenuItem(
                              value: category,
                              child: Text(category.tr()),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 24),

                  // Section Title
                  Text(
                    "select_places".tr(),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Fetched places list
                  BlocBuilder<PlaceBloc, PlaceState>(
                    builder: (context, state) {
                      if (state is PlaceOperationLoading) {
                        return const Center(child: CircularProgressIndicator());
                      } else if (state is PlacesLoaded) {
                        return Container(
                          height: 300,
                          decoration: BoxDecoration(
                            border: Border.all(color: borderColor),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ListView.separated(
                            itemCount: state.places.length,
                            separatorBuilder: (context, index) =>
                                Divider(color: borderColor),
                            itemBuilder: (context, index) {
                              final place = state.places[index];
                              final isSelected = selectedPlaces.contains(place);
                              return ListTile(
                                title: Text(
                                  place.name,
                                  style: TextStyle(color: textColor),
                                ),
                                trailing: Checkbox(
                                  activeColor: primaryColor,
                                  checkColor: Colors.white,
                                  fillColor: WidgetStateProperty.resolveWith(
                                    (states) => isDarkMode
                                        ? Colors.white10
                                        : Colors.white,
                                  ),
                                  value: isSelected,
                                  onChanged: (bool? value) {
                                    setState(() {
                                      if (value == true) {
                                        selectedPlaces.add(place);
                                      } else {
                                        selectedPlaces.remove(place);
                                      }
                                    });
                                  },
                                ),
                              );
                            },
                          ),
                        );
                      } else if (state is PlaceOperationError) {
                        return Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            state.message,
                            style: TextStyle(color: textColor),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                  const SizedBox(height: 24),

                  // Create List Button
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: () {
                      if (selectedCategory != null &&
                          selectedPlaces.isNotEmpty) {
                        Navigator.pop(context, {
                          "category": selectedCategory,
                          "places": selectedPlaces,
                        });
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("select_category_and_place".tr()),
                          ),
                        );
                      }
                    },
                    child: Text(
                      "create_list".tr(),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
