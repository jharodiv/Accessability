import 'package:accessability/accessability/logic/bloc/auth/auth_bloc.dart';
import 'package:accessability/accessability/logic/bloc/auth/auth_event.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart'; // ✅ needed for context.read
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

class TutorialWidget {
  final GlobalKey inboxKey;
  final GlobalKey settingsKey;
  final GlobalKey youKey;
  final GlobalKey locationKey;
  final GlobalKey securityKey;
  final VoidCallback? onTutorialComplete;

  TutorialWidget({
    required this.inboxKey,
    required this.settingsKey,
    required this.youKey,
    required this.locationKey,
    required this.securityKey,
    this.onTutorialComplete,
  });

  void showTutorial(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      List<TargetFocus> targets = [];

      // --- Inbox Target ---
      targets.add(TargetFocus(
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
                        color: Colors.white),
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
      ));

      // --- Settings Target ---
      targets.add(TargetFocus(
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
                        color: Colors.white),
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
      ));

      // --- Location Target ---
      targets.add(TargetFocus(
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
                        color: Colors.white),
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
      ));

      // --- You Target ---
      targets.add(TargetFocus(
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
                    "This is the 'Favorite' button.",
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20.0,
                        color: Colors.white),
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
      ));

      // --- Security Target ---
      targets.add(TargetFocus(
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
                        color: Colors.white),
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
      ));

      // --- Coach Mark ---
      TutorialCoachMark(
        targets: targets,
        colorShadow: Colors.black,
        textSkip: "SKIP",
        paddingFocus: 10,
        opacityShadow: 0.8,
        onFinish: () {
          debugPrint("Tutorial finished ✅ marking onboarding complete");
          // 🔹 Dispatch onboarding complete here
          context.read<AuthBloc>().add(CompleteOnboardingEvent());
          onTutorialComplete?.call();
        },
        onSkip: () {
          debugPrint("Tutorial skipped ❌ marking onboarding complete anyway");
          // 🔹 Even if skipped, still mark as complete
          context.read<AuthBloc>().add(CompleteOnboardingEvent());
          onTutorialComplete?.call();
          return true;
        },
      ).show(context: context);
    });
  }
}
