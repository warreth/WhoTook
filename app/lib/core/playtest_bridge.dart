import 'playtest_bridge_stub.dart'
    if (dart.library.html) 'playtest_bridge_web.dart'
    as bridge;

void publishPlaytestState(String json) => bridge.publish(json);

String? takePlaytestCommand() => bridge.takePlaytestCommand();
