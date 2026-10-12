import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import 'ticket_list_screen.dart';

class OwnerTicketsTab extends StatelessWidget {
  final UserModel user;

  const OwnerTicketsTab({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return TicketListScreen(user: user, showAppBar: true);
  }
}