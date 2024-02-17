// ignore_for_file:constant_identifier_names, curly_braces_in_flow_control_structures

import 'package:eye_phone/repo/app_repo.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cubit/subs_cubit.dart';

class SubsWidget extends StatelessWidget {
  static const _TAG = 'SubsWidget';
  final AppRepo _repo;

  const SubsWidget(this._repo, {super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
      create: (ctx) => SubsCubit(_repo),
      child: BlocBuilder<SubsCubit, SubsState>(builder: (bCtx, state) {
        final cubit = bCtx.read<SubsCubit>();
        final data = [
          (cubit.phoneSignIn, const Icon(Icons.phone), 'Sign In with phone number'),
          (cubit.emailSignIn, const Icon(Icons.email), 'Sign in with email'),
          (
            cubit.googleSignIn,
            Image.asset('assets/img/google.png',
                frameBuilder: (fCtx, ch, frame, bool? wasSynLoaded) =>
                    Padding(padding: const EdgeInsets.only(right: 8), child: ch)),
            'Sign in with Google'
          ),
          (cubit.appleSignIn, const Icon(Icons.apple, color: Colors.black), 'Sign in with Apple')
        ];
        final longestStr = data.reduce((e1, e2) => e1.$3.length > e2.$3.length ? e1 : e2).$3;
        final maxLen = longestStr.length;
        return Padding(
            padding: EdgeInsets.fromLTRB(16, 32, 16, state.mustAuth ? MediaQuery.of(bCtx).viewInsets.bottom : 8),
            child: SingleChildScrollView(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: switch (state.uiState) {
                      SubsUiState.sign_in => [
                          const Text('You must sign in first',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 23)),
                          const SizedBox(height: 12),
                          ...data.map((tri) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.only(top: 14, bottom: 14),
                                      shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(128), side: const BorderSide())),
                                  onPressed: tri.$1,
                                  icon: tri.$2,
                                  label: Row(mainAxisSize: MainAxisSize.min, children: [
                                    if (maxLen > tri.$3.length) _PlaceHolder(longestStr, maxLen, tri.$3),
                                    Text(tri.$3,
                                        style: TextStyle(
                                            color:
                                                tri is! String && tri.$1 == cubit.appleSignIn ? Colors.black : null)),
                                    if (maxLen > tri.$3.length) _PlaceHolder(longestStr, maxLen, tri.$3)
                                  ])))),
                          const SizedBox(height: 8)
                        ],
                      SubsUiState.offer => [
                          const Text('Premium', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24)),
                          const SizedBox(height: 8),
                          Text('${_repo.productDetails?.price ?? 'error'}/month',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 43),
                              textAlign: TextAlign.center),
                          const SizedBox(height: 8),
                          ...[
                            'Remote control',
                            'Unlimited number of monitors',
                            'Unlimited number of concurrent viewers'
                          ].map((txt) => Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Row(children: [
                                const Icon(Icons.done, color: Colors.deepPurple),
                                const SizedBox(width: 16),
                                Expanded(child: Text(txt, style: const TextStyle(fontSize: 19)))
                              ]))),
                          const SizedBox(height: 48),
                          TextButton(
                              onPressed: state.loading ? null : cubit.upgrade,
                              style: TextButton.styleFrom(
                                  backgroundColor:
                                      state.loading || !state.storeAvailable ? Colors.grey : Colors.deepPurple.shade400,
                                  padding: const EdgeInsets.only(top: 11, bottom: 11, left: 124, right: 124)),
                              child: const Text('Upgrade', style: TextStyle(color: Colors.white, fontSize: 23))),
                          if (!state.storeAvailable)
                            const Text('Store is unavailable at the moment. Try again later please.',
                                style: TextStyle(color: Colors.red), textAlign: TextAlign.center)
                        ],
                      SubsUiState.sign_in_phone => [
                          const Text('Enter you phone number',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 23)),
                          TextField(
                              autofocus: true,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              keyboardType: TextInputType.phone,
                              style: const TextStyle(fontSize: 20),
                              textInputAction: TextInputAction.next,
                              controller: cubit.loginCtr,
                              decoration: InputDecoration(
                                  errorText: state.loginInvalid ? 'Invalid phone number' : null,
                                  hintText: ' phone number',
                                  prefixText: '+',
                                  suffixText: state.timerTime,
                                  prefixStyle: const TextStyle(color: Colors.black, fontSize: 20))),
                          const SizedBox(height: 8),
                          Row(children: [
                            Expanded(
                              child: ElevatedButton(
                                  onPressed: () => cubit.toState(SubsUiState.sign_in),
                                  style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.only(top: 14, bottom: 14),
                                      shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(128), side: const BorderSide())),
                                  child: const Text('BACK')),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                                child: ElevatedButton(
                                    onPressed: state.loading ? null : cubit.verify,
                                    style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.only(top: 14, bottom: 14),
                                        shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(128), side: const BorderSide())),
                                    child: const Text('NEXT')))
                          ]),
                          const SizedBox(height: 8)
                        ],
                      SubsUiState.sms => [
                          const Text('Enter code from SMS',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 23)),
                          TextField(
                              autofocus: true,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              keyboardType: TextInputType.phone,
                              style: const TextStyle(fontSize: 20),
                              textInputAction: TextInputAction.next,
                              key: const ValueKey(SubsUiState.sms),
                              textAlign: TextAlign.center,
                              decoration: InputDecoration(
                                  suffixText: state.timerTime, errorText: state.smsWrong ? 'Wrong SMS code' : null),
                              controller: cubit.smsCtr),
                          const SizedBox(height: 8),
                          Row(children: [
                            Expanded(
                              child: ElevatedButton(
                                  onPressed: () => cubit.toState(SubsUiState.sign_in_phone),
                                  style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.only(top: 14, bottom: 14),
                                      shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(128), side: const BorderSide())),
                                  child: const Text('BACK')),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                                child: ElevatedButton(
                                    key: const ValueKey(SubsUiState.sms),
                                    onPressed: state.loading ? null : cubit.verify,
                                    style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.only(top: 14, bottom: 14),
                                        shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(128), side: const BorderSide())),
                                    child: const Text('RESEND'))),
                            const SizedBox(width: 8),
                            Expanded(
                                child: ElevatedButton(
                                    onPressed: cubit.sendSms,
                                    style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.only(top: 14, bottom: 14),
                                        shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(128), side: const BorderSide())),
                                    child: const Text('NEXT')))
                          ]),
                          const SizedBox(height: 8)
                        ]
                    })));
      }));
}

class _PlaceHolder extends StatelessWidget {
  final String _str;
  final String _longestStr;
  final int _maxLen;

  const _PlaceHolder(this._longestStr, this._maxLen, this._str);

  @override
  Widget build(BuildContext context) =>
      Opacity(opacity: 0, child: Text(_longestStr.substring((_str.length + _maxLen) ~/ 2)));
}
