import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:accessability/accessability/logic/bloc/user/user_bloc.dart';
import 'package:accessability/accessability/logic/bloc/user/user_event.dart';
import 'package:accessability/accessability/logic/bloc/user/user_state.dart';

enum NameField { first, last }

class EditSingleNameScreen extends StatefulWidget {
  final String uid;
  final NameField fieldToEdit;
  final String initialValue;

  const EditSingleNameScreen({
    Key? key,
    required this.uid,
    required this.fieldToEdit,
    required this.initialValue,
  }) : super(key: key);

  @override
  State<EditSingleNameScreen> createState() => _EditSingleNameScreenState();
}

class _EditSingleNameScreenState extends State<EditSingleNameScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;
  static const int _maxLength = 15;
  static const Color _accent = Color(0xFF6750A4);

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _label =>
      widget.fieldToEdit == NameField.first ? 'First name' : 'Last name';

  String? _validator(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'Cannot be empty';
    if (v.length > _maxLength) return 'Max $_maxLength characters';
    final regex = RegExp(r"^[A-Za-zÀ-ÖØ-öø-ÿ' -]+$");
    if (!regex.hasMatch(v)) return 'Invalid characters';
    return null;
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    // get current user from bloc to read the other name
    final bloc = context.read<UserBloc>();
    final state = bloc.state;
    String first = '';
    String last = '';

    if (state is UserLoaded) {
      first = state.user.firstName ?? '';
      last = state.user.lastName ?? '';
    }

    if (widget.fieldToEdit == NameField.first) {
      first = _controller.text.trim();
    } else {
      last = _controller.text.trim();
    }

    // dispatch update
    bloc.add(UpdateUserName(uid: widget.uid, firstName: first, lastName: last));
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return BlocListener<UserBloc, UserState>(
      listener: (context, state) {
        if (state is UserUpdateSuccess) {
          // purple SnackBar and pop true
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Name updated'),
              backgroundColor: const Color(0xFF6750A4), // purple
            ),
          );
          Navigator.of(context).pop(true);
        } else if (state is UserUpdateFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${state.message}')),
          );
        } else if (state is UserError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${state.message}')),
          );
        }
      },
      child: Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(65),
          child: Container(
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.grey[900] : Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  offset: const Offset(0, 1),
                  blurRadius: 2,
                ),
              ],
            ),
            child: AppBar(
              elevation: 0,
              leading: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back),
                color: const Color(0xFF6750A4),
              ),
              title: Text(
                _label,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2E2E2E),
                ),
              ),
              centerTitle: true,
              backgroundColor: Colors.transparent,
              actions: [
                BlocBuilder<UserBloc, UserState>(
                  builder: (context, state) {
                    final loading =
                        state is UserLoading || state is UserUpdating;
                    return TextButton(
                      onPressed: loading ? null : _save,
                      child: loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save',
                              style: TextStyle(
                                  fontSize: 16, color: Color(0xFF6750A4))),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // subtle label (optional)
                  Text(_label,
                      style:
                          const TextStyle(color: Colors.black54, fontSize: 14)),
                  TextFormField(
                    controller: _controller,
                    validator: _validator,
                    maxLength: _maxLength,
                    style: const TextStyle(fontSize: 20),
                    decoration: InputDecoration(
                      counterText: '',
                      enabledBorder: const UnderlineInputBorder(
                        borderSide:
                            BorderSide(color: Color(0xFFBDBDBD), width: 1),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: _accent, width: 2),
                      ),
                      contentPadding: const EdgeInsets.only(top: 12, bottom: 8),
                      isDense: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
