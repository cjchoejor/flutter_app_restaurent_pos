import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pos_system_legphel/services/room_reservation_service.dart';

part 'room_reservation_event.dart';
part 'room_reservation_state.dart';

class RoomReservationBloc
    extends Bloc<RoomReservationEvent, RoomReservationState> {
  RoomReservationBloc() : super(RoomReservationInitial()) {
    on<CheckRoomReservation>(_onCheckRoomReservation);
    on<ClearRoomReservation>(_onClearRoomReservation);
  }

  Future<void> _onCheckRoomReservation(
    CheckRoomReservation event,
    Emitter<RoomReservationState> emit,
  ) async {
    emit(RoomReservationLoading());

    try {
      final reservationData =
          await RoomReservationService.checkRoomReservation(event.roomNo);

      emit(RoomReservationLoaded(
        roomNo: reservationData['room_no'],
        reservationRefNo: reservationData['reservation_ref_no'],
      ));
    } on RoomReservationException catch (e) {
      emit(RoomReservationError(e.message));
    } catch (e) {
      emit(RoomReservationError('Failed to check room reservation: $e'));
    }
  }

  void _onClearRoomReservation(
    ClearRoomReservation event,
    Emitter<RoomReservationState> emit,
  ) {
    emit(RoomReservationInitial());
  }
}
