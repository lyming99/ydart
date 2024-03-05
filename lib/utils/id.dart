import 'package:ydart/utils/encoding.dart';

class ID {
  int client;
  int clock;

  ID({
    required this.client,
    required this.clock,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ID &&
          runtimeType == other.runtimeType &&
          client == other.client &&
          clock == other.clock;

  @override
  int get hashCode => client.hashCode ^ clock.hashCode;

  void write(AbstractEncoder encoder) {
    encoder.writeVarInt(client);
    encoder.writeVarInt(clock);
  }
  static ID read(AbstractDecoder decoder){
    var client = decoder.readVarInt();
    var clock = decoder.readVarInt();
    return ID(client: client, clock: clock);
  }
}
