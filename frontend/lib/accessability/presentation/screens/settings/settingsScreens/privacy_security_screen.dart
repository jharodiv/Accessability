import 'package:flutter/material.dart';

class Privacysecurity extends StatelessWidget {
  const Privacysecurity({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading:
            IconButton(onPressed: () {}, icon: const Icon(Icons.arrow_back)),
        title: const Text(
          'Privacy & Security',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Container(
        margin: const EdgeInsets.all(15),
        child: ListView(
          children: [
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.grey,
                    blurRadius: 2,
                    offset: Offset(1, 1),
                  ),
                ],
              ),
              child: Container(
                  margin: const EdgeInsets.all(10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: Container(
                            width: 100,
                            height: 100,
                            color: Colors.grey,
                          )),
                      const Expanded(
                          child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            'Your privacy is our priority',
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'We prioritize your privacy and security by securely storing your information, using it responsibly, and implementing advanced encryption and safeguards to protect against unauthorized access',
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w300),
                          ),
                        ],
                      ))
                    ],
                  )),
            ),
            Container(
                height: 50,
                width: double.infinity,
                margin: const EdgeInsets.only(top: 10),
                child: const Stack(
                  children: [
                    Positioned(
                      top: 10,
                      left: 0,
                      bottom: 0,
                      child: Text('Data Security',
                          style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w600)),
                    )
                  ],
                )),
            const Divider(
              height: 0.1,
              color: Colors.black12,
            ),
            Container(
                height: 50,
                width: double.infinity,
                margin: EdgeInsets.only(top: 10),
                child: const Stack(
                  children: [
                    Positioned(
                      top: 10,
                      left: 0,
                      bottom: 0,
                      child: Text('Additional Data Rights',
                          style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w600)),
                    )
                  ],
                )),
            const Divider(
              height: 0.1,
              color: Colors.black12,
            ),
            GestureDetector(
                onTap: () {},
                child: Container(
                    height: 50,
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    child: const Stack(
                      children: [
                        Positioned(
                          top: 10,
                          left: 0,
                          bottom: 0,
                          child: Text('Privacy Policy',
                              style: TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w600)),
                        )
                      ],
                    )))
          ],
        ),
      ),
    );
  }
}
