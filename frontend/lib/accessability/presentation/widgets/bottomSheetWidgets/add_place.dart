import 'package:flutter/material.dart';

class AddPlaceWidget extends StatefulWidget {
  @override
  _AddPlaceWidgetState createState() => _AddPlaceWidgetState();
}

class _AddPlaceWidgetState extends State<AddPlaceWidget> {
  List<String> places = [];

  void _addNewPlace(String place) {
    setState(() {
      places.add(place);
    });
  }

  void _removePlace(int index) {
    setState(() {
      places.removeAt(index);
    });
  }

  void _navigateToAddNewPlace() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: AddPlaceForm(onPlaceAdded: _addNewPlace),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          leading: const CircleAvatar(
            backgroundColor: Color(0xFF6750A4),
            child: Icon(Icons.add, color: Colors.white),
          ),
          title: const Text(
            "Add a new Place",
            style: TextStyle(
              color: Color(0xFF6750A4), fontWeight: FontWeight.bold,
              fontSize: 16.0, // Adjust this value to make the text smaller
            ),
          ),
          onTap: _navigateToAddNewPlace,
        ),
        Divider(),
        if (places.isNotEmpty)
          Column(
            children: places.map((place) {
              return ListTile(
                leading: const Icon(Icons.place, color: Color(0xFF6750A4)),
                title: Text(place),
                trailing: IconButton(
                  icon: Icon(Icons.close),
                  onPressed: () => _removePlace(places.indexOf(place)),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }
}

class AddPlaceForm extends StatefulWidget {
  final Function(String) onPlaceAdded;
  AddPlaceForm({required this.onPlaceAdded});

  @override
  _AddPlaceFormState createState() => _AddPlaceFormState();
}

class _AddPlaceFormState extends State<AddPlaceForm> {
  final TextEditingController _controller = TextEditingController();

  void _submit() {
    if (_controller.text.isNotEmpty) {
      widget.onPlaceAdded(_controller.text);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            decoration: InputDecoration(
              labelText: "Search address or location name",
              prefixIcon: Icon(Icons.place),
            ),
          ),
          SizedBox(height: 20),
          ElevatedButton(
            onPressed: _submit,
            child: Text("Add Place"),
          ),
        ],
      ),
    );
  }
}
