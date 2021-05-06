import 'package:expiscan/service/notification_service.dart';
import 'package:flutter/material.dart';
// import 'package:flutter/rendering.dart';
import 'package:shared_preferences/shared_preferences.dart';

bool showDatabaseEntriesId = false;

class SettingsPage extends StatefulWidget {
  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  Future<SharedPreferences> prefsInstance = SharedPreferences.getInstance();

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
        future: prefsInstance,
        builder: (context, AsyncSnapshot<SharedPreferences> snapshot) {
          if (snapshot.connectionState == ConnectionState.done &&
              snapshot.hasData) {
            SharedPreferences prefs = snapshot.data!;
            return ListView(
              children: [
                // SwitchListTile(
                //   title: Text('DEBUG: Enable Layout Bounds'),
                //   secondary: Icon(Icons.bug_report),
                //   onChanged: (value) {
                //     setState(() {
                //       debugPaintSizeEnabled = value;
                //     });
                //   },
                //   value: debugPaintSizeEnabled,
                // ),
                // SwitchListTile(
                //   title: Text('DEBUG: Enable Pointer Touch'),
                //   secondary: Icon(Icons.bug_report),
                //   onChanged: (value) {
                //     setState(() {
                //       debugPaintPointersEnabled = value;
                //     });
                //   },
                //   value: debugPaintPointersEnabled,
                // ),
                // SwitchListTile(
                //   title: Text('Toggle Database Entries ID'),
                //   secondary: Icon(Icons.bug_report_rounded),
                //   value: showDatabaseEntriesId,
                //   onChanged: (value) {
                //     setState(() {
                //       showDatabaseEntriesId = value;
                //     });
                //   },
                // ),
                // ListTile(
                //   title: Text('Check pending notifications'),
                //   trailing: ElevatedButton(
                //     child: Icon(Icons.ring_volume),
                //     onPressed: () {
                //       notificationService.getAllNotifications();
                //     },
                //   ),
                // ),
                SwitchListTile(
                  title: Text('Expiration Date Push Notifications'),
                  secondary: Icon(Icons.notifications),
                  value: prefs.getBool('notificationService') ?? false,
                  onChanged: (value) async {
                    await prefs.setBool('notificationService', value);
                    await initNotificationService();
                    setState(() {});
                  },
                ),
                ListTile(
                  leading: Icon(Icons.info),
                  title: Text('About app'),
                  onTap: () {
                    showAboutDialog(
                        context: context,
                        applicationIcon: Icon(Icons.local_restaurant_rounded),
                        applicationLegalese:
                            'Created by David \n Scanned product\'s name and image provided by Open Food Facts',
                        applicationVersion: '1.0');
                  },
                ),
              ],
            );
          } else {
            return Center(child: CircularProgressIndicator());
          }
        });
  }
}
