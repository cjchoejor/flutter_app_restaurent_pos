part of 'room_reservation_bloc.dart';

abstract class RoomReservationEvent extends Equatable {
  const RoomReservationEvent();

  @override
  List<Object?> get props => [];
}

class CheckRoomReservation extends RoomReservationEvent {
  final int roomNo;

  const CheckRoomReservation(this.roomNo);

  @override
  List<Object?> get props => [roomNo];
}

class ClearRoomReservation extends RoomReservationEvent {
  const ClearRoomReservation();
}
