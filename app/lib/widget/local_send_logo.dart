import 'package:flutter/material.dart';
import 'package:localsend_app/gen/assets.gen.dart';
import 'package:localsend_app/gen/strings.g.dart';

class LocalSendLogo extends StatelessWidget {
  final bool withText;

  // ignore: prefer_const_constructors_in_immutables -- uses runtime t.appName when withText is true
  LocalSendLogo({required this.withText});

  @override
  Widget build(BuildContext context) {
    final logo = ColorFiltered(
      colorFilter: ColorFilter.mode(
        Theme.of(context).colorScheme.primary,
        BlendMode.srcATop,
      ),
      child: Assets.img.logo512.image(
        width: 200,
        height: 200,
      ),
    );

    if (withText) {
      return Column(
        children: [
          logo,
          Text(
            t.appName,
            style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ],
      );
    } else {
      return logo;
    }
  }
}
