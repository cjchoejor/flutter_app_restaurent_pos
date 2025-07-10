import 'package:equatable/equatable.dart';

class RoomNoModel extends Equatable {
  final String roomNumber;
  final String? roomType;

  const RoomNoModel({
    required this.roomNumber,
    this.roomType,
  });

  // Convert RoomNoModel to a map for database storage
  Map<String, dynamic> toMap() {
    return {
      'roomNumber': roomNumber,
      'roomType': roomType,
    };
  }

  // Convert map (from database) to RoomNoModel
  factory RoomNoModel.fromMap(Map<String, dynamic> map) {
    return RoomNoModel(
      roomNumber: map['roomNumber'] ?? '',
      roomType: map['roomType'],
    );
  }

  // CopyWith method for updating room details
  RoomNoModel copyWith({
    String? roomNumber,
    String? roomType,
  }) {
    return RoomNoModel(
      roomNumber: roomNumber ?? this.roomNumber,
      roomType: roomType ?? this.roomType,
    );
  }

  @override
  List<Object?> get props => [roomNumber, roomType];
}
