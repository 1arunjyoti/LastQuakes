import 'package:hive/hive.dart';
import 'package:lastquake/models/earthquake.dart';

/// Hive TypeAdapter for Earthquake model
/// TypeId 0 is reserved for Earthquake
class EarthquakeAdapter extends TypeAdapter<Earthquake> {
  @override
  final int typeId = 0;

  @override
  Earthquake read(BinaryReader reader) {
    return Earthquake(
      id: reader.readString(),
      magnitude: reader.readDouble(),
      place: reader.readString(),
      time: DateTime.fromMillisecondsSinceEpoch(reader.readInt()),
      latitude: reader.readDouble(),
      longitude: reader.readDouble(),
      depth: reader.readBool() ? reader.readDouble() : null,
      url: reader.readBool() ? reader.readString() : null,
      tsunami: reader.readBool() ? reader.readInt() : null,
      source: reader.readString(),
      rawData: Map<String, dynamic>.from(reader.readMap()),
    );
  }

  @override
  void write(BinaryWriter writer, Earthquake obj) {
    writer.writeString(obj.id);
    writer.writeDouble(obj.magnitude);
    writer.writeString(obj.place);
    writer.writeInt(obj.time.millisecondsSinceEpoch);
    writer.writeDouble(obj.latitude);
    writer.writeDouble(obj.longitude);

    // Handle nullable depth
    writer.writeBool(obj.depth != null);
    if (obj.depth != null) {
      writer.writeDouble(obj.depth!);
    }

    // Handle nullable url
    writer.writeBool(obj.url != null);
    if (obj.url != null) {
      writer.writeString(obj.url!);
    }

    // Handle nullable tsunami
    writer.writeBool(obj.tsunami != null);
    if (obj.tsunami != null) {
      writer.writeInt(obj.tsunami!);
    }

    writer.writeString(obj.source);
    writer.writeMap(obj.rawData);
  }
}
