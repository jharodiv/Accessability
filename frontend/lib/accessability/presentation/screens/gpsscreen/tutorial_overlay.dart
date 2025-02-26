import 'package:flutter/material.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

class TutorialOverlay {
  static void showTutorial(
    BuildContext context, {
    required GlobalKey inboxKey,
    required GlobalKey settingsKey,
    required GlobalKey locationKey,
    required GlobalKey youKey,
    required GlobalKey securityKey,
  }) {
    final targets = <TargetFocus>[
      TargetFocus(
        identify: "inboxTarget",
        keyTarget: inboxKey,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            child: Container(
              color: Colors.transparent,
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "This is your inbox.",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20.0,
                      color: Colors.white,
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(top: 10.0),
                    child: Text(
                      "Tap here to view your messages.",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      TargetFocus(
        identify: "settingsTarget",
        keyTarget: settingsKey,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            child: Container(
              color: Colors.transparent,
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "This is the settings button.",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20.0,
                      color: Colors.white,
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(top: 10.0),
                    child: Text(
                      "Tap here to access settings.",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      TargetFocus(
        identify: "locationTarget",
        keyTarget: locationKey,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            child: Container(
              color: Colors.transparent,
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "This is the location button.",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20.0,
                      color: Colors.white,
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(top: 10.0),
                    child: Text(
                      "Tap here to view your location.",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      TargetFocus(
        identify: "youTarget",
        keyTarget: youKey,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            child: Container(
              color: Colors.transparent,
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "This is the 'You' button.",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20.0,
                      color: Colors.white,
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(top: 10.0),
                    child: Text(
                      "Tap here to view your profile.",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      TargetFocus(
        identify: "securityTarget",
        keyTarget: securityKey,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            child: Container(
              color: Colors.transparent,
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "This is the security button.",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20.0,
                      color: Colors.white,
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(top: 10.0),
                    child: Text(
                      "Tap here to view security settings.",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ];

    TutorialCoachMark(
      targets: targets,
      colorShadow: Colors.black,
      textSkip: "SKIP",
      paddingFocus: 10,
      opacityShadow: 0.8,
      onFinish: () => print("Tutorial finished"),
      onClickTarget: (target) => print("Clicked on target: $target"),
      onSkip: () {
        print("Tutorial skipped");
        return true;
      },
    ).show(context: context);
  }
}
