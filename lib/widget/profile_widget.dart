import 'package:eye_phone/repo/app_repo.dart';
import 'package:eye_phone/util/util.dart';
import 'package:flutter/material.dart';

class ProfileWidget extends StatelessWidget {
  final AppRepo _repo;

  const ProfileWidget(this._repo, {super.key});

  @override
  Widget build(BuildContext context) {
    final isPremium = _repo.getBoolFromSp(IS_PREMIUM) ?? false;
    return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              Row(children: [
                const Text('Signed in as:', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 4),
                Expanded(child: Text(_repo.getStringFromSp(LOGIN)!, style: const TextStyle(fontSize: 18)))
              ]),
              const SizedBox(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('PLAN:', style: TextStyle(fontWeight: FontWeight.bold)),
                isPremium
                    ? const Text('PREMIUM', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple))
                    : const Text('BASIC')
              ]),
              if (!(isPremium))
                Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: TextButton(
                        onPressed: () => showSubsBottomSheet(context, _repo, false),
                        style: TextButton.styleFrom(
                            backgroundColor: Colors.deepPurple.shade400,
                            padding: const EdgeInsets.only(top: 4, bottom: 4, left: 60, right: 60)),
                        child: const Text('Upgrade', style: TextStyle(color: Colors.white, fontSize: 23))))
            ])));
  }
}
