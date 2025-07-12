part of 'room_reservation_bloc.dart';

abstract class RoomReservationState extends Equatable {
  const RoomReservationState();

  @override
  List<Object?> get props => [];
}

class RoomReservationInitial extends RoomReservationState {}

class RoomReservationLoading extends RoomReservationState {}

class RoomReservationLoaded extends RoomReservationState {
  final int roomNo;
  final String reservationRefNo;

  const RoomReservationLoaded({
    required this.roomNo,
    required this.reservationRefNo,
  });

  @override
  List<Object?> get props => [roomNo, reservationRefNo];
}

class RoomReservationError extends RoomReservationState {
  final String message;

  const RoomReservationError(this.message);

  @override
  List<Object?> get props => [message];
}
