import 'package:flutter/material.dart';
import '../main.dart';
import '../pages/about.dart';
import '../pages/documentation.dart';
import '../pages/settings.dart';
import '../pages/zebra_assist.dart';

class UnconnectedMenu extends StatelessWidget {
  const UnconnectedMenu({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      child: ListView(
        children: [
          Container(
            padding: EdgeInsets.all(16.0),
            decoration: BoxDecoration(color: Colors.white),
            child: Text(
              'Menu',
              style: TextStyle(color: Colors.black, fontSize: 24),
            ),
          ),
          Divider(
            thickness: 1,
            color: Colors.black,
            indent: 16.0,
            endIndent: 16.0,
          ),
          ListTile(
            leading: Icon(Icons.home_outlined),
            title: Text('Home'),
            onTap: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder:
                      (context) => const MyHomePage(title: 'Printer Setup'),
                ),
                (Route<dynamic> route) => false,
              );
            },
          ),
          Divider(
            thickness: 1,
            color: Colors.black,
            indent: 16.0,
            endIndent: 16.0,
          ),
          ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Documentation'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => DocumentationPage()),
              );
            },
          ),
          Divider(
            thickness: 1,
            color: Colors.black,
            indent: 16.0,
            endIndent: 16.0,
          ),
          ListTile(
            leading: Icon(Icons.help_outline),
            title: Text('Zebra Assist'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ZebraAssist()),
              );
            },
          ),
          Divider(
            thickness: 1,
            color: Colors.black,
            indent: 16.0,
            endIndent: 16.0,
          ),
          ListTile(
            leading: Icon(Icons.print_outlined),
            title: Text('About'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AboutPage()),
              );
            },
          ),
          Divider(
            thickness: 1,
            color: Colors.black,
            indent: 16.0,
            endIndent: 16.0,
          ),
          ListTile(
            leading: Icon(Icons.settings_outlined),
            title: Text('App Settings'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SettingsPage()),
              );
            },
          ),
          Divider(
            thickness: 1,
            color: Colors.black,
            indent: 16.0,
            endIndent: 16.0,
          ),
        ],
      ),
    );
  }
}
