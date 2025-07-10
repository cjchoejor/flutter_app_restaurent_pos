import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pos_system_legphel/bloc/room_bloc/bloc/add_room_bloc.dart';
import 'package:pos_system_legphel/views/pages/Add%20Items/add_room_page.dart';

class AddNewRoom extends StatefulWidget {
  const AddNewRoom({super.key});

  @override
  State<AddNewRoom> createState() => _AddNewRoomState();
}

class _AddNewRoomState extends State<AddNewRoom> {
  @override
  void initState() {
    // ← ADD THIS METHOD HERE
    super.initState();
    // Load rooms when the widget is first created
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RoomBloc>().add(LoadRooms());
    });
  }

  @override
  Widget build(BuildContext context) {
    // ← YOUR EXISTING BUILD METHOD STAYS THE SAME
    return Stack(
      children: [
        // Main content of the screen
        BlocBuilder<RoomBloc, RoomState>(
          builder: (context, state) {
            if (state is RoomLoading) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            } else if (state is RoomLoaded) {
              return ListView.builder(
                itemCount: state.rooms.length,
                itemBuilder: (context, index) {
                  final room = state.rooms[index];
                  return Column(
                    children: [
                      GestureDetector(
                        onTap: () {
                          // Navigate to a new page to edit/update room details
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AddRoomPage(
                                roomModel: room,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 8.0),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                          child: ListTile(
                            title: Text("Room ${room.roomNumber}"),
                            subtitle: Text(
                              room.roomType != null && room.roomType!.isNotEmpty
                                  ? room.roomType!
                                  : "No type assigned",
                              style: const TextStyle(color: Colors.green),
                            ),
                            trailing: IconButton(
                              onPressed: () {
                                context
                                    .read<RoomBloc>()
                                    .add(DeleteRoom(room.roomNumber));
                              },
                              icon: const Icon(Icons.delete),
                            ),
                          ),
                        ),
                      ),
                      // Divider added here between list items
                      const Divider(),
                    ],
                  );
                },
              );
            }
            return Container();
          },
        ),

        // Custom Floating Action Button -------------------------------------->
        Positioned(
          bottom: 20,
          right: 20,
          child: GestureDetector(
            onTap: () {
              Navigator.push(context, MaterialPageRoute(
                builder: (context) {
                  return const AddRoomPage();
                },
              ));
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color.fromARGB(255, 3, 27, 48),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 32),
            ),
          ),
        ),
      ],
    );
  }
}
