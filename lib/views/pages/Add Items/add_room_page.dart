import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pos_system_legphel/bloc/room_bloc/bloc/add_room_bloc.dart';
import 'package:pos_system_legphel/models/others/room_no_model.dart';

class AddRoomPage extends StatefulWidget {
  final RoomNoModel? roomModel;
  const AddRoomPage({
    super.key,
    this.roomModel,
  });

  @override
  State<AddRoomPage> createState() => _AddRoomPageState();
}

class _AddRoomPageState extends State<AddRoomPage> {
  final TextEditingController _roomNumberController = TextEditingController();
  final TextEditingController _roomTypeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.roomModel != null) {
      _roomTypeController.text = widget.roomModel!.roomType ?? '';
      _roomNumberController.text = widget.roomModel!.roomNumber;
    }
  }

  void _addRoom() {
    final roomNumber = _roomNumberController.text.trim();
    final roomType = _roomTypeController.text.trim();

    if (roomNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Room Number is required")),
      );
      return;
    }

    final newRoom = RoomNoModel(roomNumber: roomNumber, roomType: roomType);

    context.read<RoomBloc>().add(AddRoom(newRoom));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Room Added Successfully!")),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.roomModel == null ? "Add New Room" : "Edit Room",
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              TextField(
                controller: _roomNumberController,
                decoration: const InputDecoration(
                  labelText: "Room Number",
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _roomTypeController,
                decoration: const InputDecoration(
                  labelText: "Room Type (Optional)",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: _addRoom,
                    child: Text(
                      widget.roomModel == null ? "Add Room" : "Edit Room",
                    ),
                  ),
                  const SizedBox(
                    width: 20,
                  ),
                  if (widget.roomModel != null)
                    ElevatedButton(
                      onPressed: () {
                        context.read<RoomBloc>().add(DeleteRoom(
                            widget.roomModel!.roomNumber.toString()));
                        Navigator.pop(context);
                      },
                      child: const Text("Delete"),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _roomNumberController.dispose();
    _roomTypeController.dispose();
    super.dispose();
  }
}
