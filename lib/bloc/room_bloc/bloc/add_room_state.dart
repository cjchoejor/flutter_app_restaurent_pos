part of 'add_room_bloc.dart';

abstract class RoomState extends Equatable {
  const RoomState();

  @override
  List<Object?> get props => [];
}

// Initial state
class RoomInitial extends RoomState {}

// Loading state
class RoomLoading extends RoomState {}

// Loaded state (successful fetch)
class RoomLoaded extends RoomState {
  final List<RoomNoModel> rooms;

  const RoomLoaded({required this.rooms});

  @override
  List<Object?> get props => [rooms];
}

// Error state
class RoomError extends RoomState {
  final String errorMessage;

  const RoomError({required this.errorMessage});

  @override
  List<Object?> get props => [errorMessage];
}
