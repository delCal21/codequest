import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

class CreateFirstAdminPage extends StatefulWidget {
  const CreateFirstAdminPage({Key? key}) : super(key: key);
  @override
  State<CreateFirstAdminPage> createState() => _CreateFirstAdminPageState();
}

class _CreateFirstAdminPageState extends State<CreateFirstAdminPage> {
  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      return const Scaffold(
        body: Center(
          child: Text('This page is only available on web.'),
        ),
      );
    }
    // TODO: Add the rest of the page's content here
    return const SizedBox();
  }
}
