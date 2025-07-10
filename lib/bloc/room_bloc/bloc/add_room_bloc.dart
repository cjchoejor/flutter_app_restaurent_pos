import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pos_system_legphel/SQL/room_database_helper.dart';
import 'package:pos_system_legphel/models/others/room_no_model.dart';

part 'add_room_event.dart';
part 'add_room_state.dart';

class RoomBloc extends Bloc<RoomEvent, RoomState> {
  final RoomDatabaseHelper _roomDatabase = RoomDatabaseHelper.instance;

  RoomBloc() : super(RoomInitial()) {
    on<LoadRooms>(_onLoadRooms);
    on<AddRoom>(_onAddRoom);
    on<UpdateRoom>(_onUpdateRoom);
    on<DeleteRoom>(_onDeleteRoom);
  }

  // Load Rooms from Database
  void _onLoadRooms(LoadRooms event, Emitter<RoomState> emit) async {
    emit(RoomLoading());
    try {
      final rooms = await _roomDatabase.fetchRooms();
      emit(RoomLoaded(rooms: rooms));
    } catch (e) {
      emit(RoomError(errorMessage: "Failed to load rooms: $e"));
    }
  }

  // Add a new Room
  void _onAddRoom(AddRoom event, Emitter<RoomState> emit) async {
    try {
      await _roomDatabase.insertRoom(event.room);
      add(LoadRooms());
    } catch (e) {
      emit(RoomError(errorMessage: "Failed to add room: $e"));
    }
  }

  // Update an existing Room
  void _onUpdateRoom(UpdateRoom event, Emitter<RoomState> emit) async {
    try {
      await _roomDatabase.updateRoom(event.room);
      add(LoadRooms());
    } catch (e) {
      emit(RoomError(errorMessage: "Failed to update room: $e"));
    }
  }

  // Delete a Room
  void _onDeleteRoom(DeleteRoom event, Emitter<RoomState> emit) async {
    try {
      await _roomDatabase.deleteRoom(event.roomNumber);
      add(LoadRooms());
    } catch (e) {
      emit(RoomError(errorMessage: "Failed to delete room: $e"));
    }
  }
}
