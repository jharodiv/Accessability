import 'package:flutter/material.dart';

class Bottomwidgets extends StatelessWidget {
  const Bottomwidgets({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            color: Colors.blueAccent,
            child: const Center(
              child: Text(
                'Main Body',
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),
          ),
          DraggableScrollableSheet(
              initialChildSize: 0.2,
              minChildSize: 0.2,
              maxChildSize: 0.8,
              builder:
                  (BuildContext context, ScrollController scrollController) {
                return Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 10,
                        offset: Offset(0, -5),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    controller: scrollController,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                          minHeight: MediaQuery.of(context).size.height * 0.8),
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Container(
                              width: 90,
                              height: 5,
                              decoration: BoxDecoration(
                                  color: Colors.grey,
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              })
        ],
      ),
    );
  }
}
