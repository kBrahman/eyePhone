sealed class AppEvent {
  const AppEvent();
}

class StopTimer extends AppEvent {
  final bool stop;

  const StopTimer(this.stop);
}

class DeleteMon extends AppEvent {
  final int index;

  const DeleteMon(this.index);
}

class Turn extends AppEvent {
  final bool on;

  const Turn({required this.on});
}

class AddCam extends AppEvent {
  final String id;

  const AddCam({required this.id});
}

class ShowCam extends AppEvent {}

class RequestPermission extends AppEvent {}

class QrVisible extends AppEvent {
  final bool value;

  const QrVisible(this.value);
}

class GoLive extends AppEvent {
  const GoLive();
}

class Tick extends AppEvent {
  final int sec;

  const Tick(this.sec);
}
