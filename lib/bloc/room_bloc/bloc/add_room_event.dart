part of 'add_room_bloc.dart';

abstract class RoomEvent extends Equatable {
  const RoomEvent();

  @override
  List<Object?> get props => [];
}

// Load all rooms from DB
class LoadRooms extends RoomEvent {}

// Add a new room
class AddRoom extends RoomEvent {
  final RoomNoModel room;

  const AddRoom(this.room);

  @override
  List<Object?> get props => [room];
}

// Update an existing room
class UpdateRoom extends RoomEvent {
  final RoomNoModel room;

  const UpdateRoom(this.room);

  @override
  List<Object?> get props => [room];
}

// Delete a room
class DeleteRoom extends RoomEvent {
  final String roomNumber;

  const DeleteRoom(this.roomNumber);

  @override
  List<Object?> get props => [roomNumber];
}
