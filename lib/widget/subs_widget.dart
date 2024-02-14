import 'package:eye_phone/main.dart';
import 'package:eye_phone/repo/app_repo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cubit/subs_cubit.dart';

class SubsWidget extends StatelessWidget {
  final AppRepo _repo;

  const SubsWidget(this._repo, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
        padding: const EdgeInsets.fromLTRB(16, 32, 16, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Premium', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24)),
          const SizedBox(height: 8),
          const Text('\$0.99/month',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 43), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          ...['Remote control', 'Unlimited number of monitors', 'Unlimited number of concurrent viewers']
              .map((txt) => Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(children: [
                    const Icon(Icons.done, color: Colors.deepPurple),
                    const SizedBox(width: 16),
                    Expanded(child: Text(txt, style: const TextStyle(fontSize: 19)))
                  ]))),
          const Spacer(),
          BlocProvider(
              create: (ctx) => SubsCubit(_repo),
              child: BlocBuilder<SubsCubit, PremiumState>(
                  builder: (bCtx, state) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        TextButton(
                            onPressed: () => bCtx.read<SubsCubit>().upgrade(),
                            style: TextButton.styleFrom(
                                backgroundColor: state.loading ? Colors.grey : Colors.deepPurple.shade400,
                                padding: const EdgeInsets.only(top: 8, bottom: 8)),
                            child: const Text('Upgrade', style: TextStyle(color: Colors.white, fontSize: 21))),
                        if (!state.storeAvailable)
                          const Text('Could not proceed. Try again later please',
                              style: TextStyle(color: Colors.red), textAlign: TextAlign.center)
                      ])))
        ]));
  }
}
