import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import 'ticket_list_screen.dart';

class ClientTicketsTab extends StatelessWidget {
  final UserModel user;

  const ClientTicketsTab({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return TicketListScreen(user: user, showAppBar: true);
  }
}