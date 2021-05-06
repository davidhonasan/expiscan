import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:expiscan/service/database_service.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class CircleMaterialButton extends StatelessWidget {
  final Widget? child;
  final EdgeInsets? padding;
  final void Function()? onPressed;

  CircleMaterialButton(
      {this.child, this.padding = const EdgeInsets.all(8), this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
        style: ButtonStyle(
            shape: MaterialStateProperty.all(CircleBorder()),
            padding: MaterialStateProperty.all(padding)),
        child: child,
        onPressed: onPressed);
  }
}

class EmptyListPage extends StatelessWidget {
  final String phrase;

  EmptyListPage({this.phrase = ''});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(50),
      child: DefaultTextStyle(
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.grey),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              phrase == 'Pantry' ? Icons.kitchen : Icons.fastfood,
              size: MediaQuery.of(context).size.width / 3,
              color: Theme.of(context).accentColor.withOpacity(0.5),
            ),
            SizedBox(height: 15),
            Text(
              phrase.isEmpty
                  ? 'It\'s time to add!'
                  : 'It\'s time to add a new $phrase!',
              style: TextStyle(fontSize: 28, color: Colors.black54),
            ),
            SizedBox(height: 10),
            Text(
              'Use the + button to add and it will show up in here.',
              style: TextStyle(fontSize: 18),
            )
          ],
        ),
      ),
    );
  }
}

class SmartImageHandler extends StatelessWidget {
  final String? imagePath;
  final double iconSize;
  SmartImageHandler({required this.imagePath, this.iconSize = 100});

  Future<bool> _checkImageAccessible(String? imagePath) async {
    try {
      if (imagePath == null) return false;
      if (imagePath.isNotEmpty) {
        if (imagePath.contains(RegExp(r'^(https?)'))) return true;
        if (await File(imagePath).exists()) return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _checkImageAccessible(imagePath),
      builder: (BuildContext context, AsyncSnapshot<dynamic> snapshot) {
        if (snapshot.hasData &&
            snapshot.connectionState == ConnectionState.done) {
          return snapshot.data
              ? (imagePath!.contains(RegExp(r'^(https?)'))
                  ? CachedNetworkImage(
                      imageUrl: imagePath!,
                      progressIndicatorBuilder:
                          (context, url, downloadProgress) => Center(
                        child: CircularProgressIndicator(
                            value: downloadProgress.progress),
                      ),
                      errorWidget: (context, url, error) => Icon(Icons.error),
                      fit: BoxFit.cover,
                    )
                  : Image.file(
                      File(imagePath!),
                      fit: BoxFit.cover,
                    ))
              : Icon(
                  Icons.image_not_supported_rounded,
                  size: iconSize,
                  color: Colors.grey,
                );
        } else {
          return Center(child: CircularProgressIndicator());
        }
      },
    );
  }
}

class ImagePickerFormField extends StatefulWidget {
  final double? height;
  final TextEditingController? controller;
  ImagePickerFormField({this.height = 300, this.controller});

  @override
  _ImagePickerFormFieldState createState() => _ImagePickerFormFieldState();
}

class _ImagePickerFormFieldState extends State<ImagePickerFormField> {
  late File _image;
  final picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _image = File(widget.controller!.text);
    }
  }

  Future pickImage(String from) async {
    PickedFile? pickedFile;

    try {
      pickedFile = await picker.getImage(
          imageQuality: 50,
          source: from == 'camera' ? ImageSource.camera : ImageSource.gallery);
    } catch (e) {
      return 0;
    }

    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile!.path);
        widget.controller!.text = pickedFile.path;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 25),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
                border: Border.all(color: Colors.black26),
                borderRadius: BorderRadius.circular(10)),
            width: MediaQuery.of(context).size.width,
            height: widget.height! - 30,
            margin: EdgeInsets.only(bottom: 30),
            child: Stack(
              fit: StackFit.expand,
              children: [SmartImageHandler(imagePath: _image.path)],
            ),
          ),
          Positioned(
              bottom: 0,
              right: 70,
              child: CircleMaterialButton(
                padding: EdgeInsets.all(12),
                child: Icon(
                  Icons.add_a_photo,
                  size: 35,
                ),
                onPressed: () => pickImage('camera'),
              )),
          Positioned(
              bottom: 0,
              right: 0,
              child: CircleMaterialButton(
                padding: EdgeInsets.all(12),
                child: Icon(
                  Icons.add_photo_alternate,
                  size: 35,
                ),
                onPressed: () => pickImage('gallery'),
              ))
        ],
      ),
    );
  }
}

Future<dynamic> showDeleteDialog(
        {required BuildContext context,
        required String table,
        required DatabaseEntry entry}) =>
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) => AlertDialog(
              title: Text('Delete Item?'),
              content: SingleChildScrollView(
                child: ListBody(
                  children: <Widget>[
                    Text('Do you want to delete this item?'),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: Text('CANCEL'),
                  onPressed: () => Navigator.pop(context, false),
                ),
                TextButton(
                    child: Text('DELETE'),
                    onPressed: () async {
                      await ExpiscanDB.deleteEntry(table, entry);
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Deleting data...')));
                      return Navigator.pop(context, true);
                    },
                    style: TextButton.styleFrom(primary: Colors.red)),
              ],
            ));
