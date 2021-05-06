import 'package:expiscan/screens/settings_page.dart';
import 'package:expiscan/constants/constants.dart';
import 'package:expiscan/widgets.dart';
import 'package:expiscan/service/database_service.dart';
import 'package:flutter/material.dart';

class PantryPage extends StatefulWidget {
  @override
  _PantryPageState createState() => _PantryPageState();
}

class _PantryPageState extends State<PantryPage> {
  Future<dynamic> _openDetail(Widget detailPage) async {
    return await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => detailPage),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
        future: ExpiscanDB.getEntries(pantryTableName),
        builder: (BuildContext context, AsyncSnapshot<dynamic> pantryList) {
          if (pantryList.hasData && pantryList.data.isNotEmpty) {
            return GridView.builder(
              padding: const EdgeInsets.only(bottom: 50),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, mainAxisExtent: 300),
              itemCount: pantryList.hasData ? pantryList.data.length : 0,
              itemBuilder: (BuildContext context, int index) {
                var pantryEntry = pantryList.data[index];

                return Container(
                  padding: const EdgeInsets.all(8),
                  child: Card(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                              child: SmartImageHandler(
                                  imagePath: pantryEntry.picturePath)),
                          Container(
                              child: ListTile(
                            title: Text('${pantryEntry.name}'),
                            subtitle: showDatabaseEntriesId
                                ? Text('ID: ${pantryEntry.id}')
                                : null,
                            contentPadding:
                                const EdgeInsets.fromLTRB(20, 0, 5, 0),
                            trailing: PopupMenuButton(
                              icon: Icon(Icons.more_vert),
                              padding: EdgeInsets.zero,
                              onSelected: (value) async {
                                if (value == 0) {
                                  await _openDetail(PantryDetailPage(
                                      isAdding: false, entry: pantryEntry));
                                } else {
                                  await showDeleteDialog(
                                      context: context,
                                      table: pantryTableName,
                                      entry: pantryEntry);
                                }
                                setState(() {});
                              },
                              itemBuilder: (BuildContext context) => [
                                PopupMenuItem(
                                    child: Text('Edit Pantry'), value: 0),
                                PopupMenuItem(
                                    child: Text('Delete Pantry'), value: 1),
                              ],
                            ),
                          ))
                        ]),
                  ),
                );
              },
            );
          } else {
            return EmptyListPage(
              phrase: 'Pantry',
            );
          }
        });
  }
}

// Detail / edit

class PantryDetailPage extends StatefulWidget {
  final bool isAdding;
  final Pantry? entry;

  PantryDetailPage({required this.isAdding, this.entry});

  @override
  _PantryDetailPageState createState() => _PantryDetailPageState();
}

class _PantryDetailPageState extends State<PantryDetailPage> {
  final _formKey = GlobalKey<FormState>();
  final _formName = TextEditingController();
  final _formImage = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (!widget.isAdding) {
      _formName.text = widget.entry!.name;
      _formImage.text = widget.entry!.picturePath;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
        key: _formKey,
        child: Scaffold(
            appBar: AppBar(
              title: widget.isAdding ? Text('Add Pantry') : Text('Edit Pantry'),
              actions: <Widget>[
                IconButton(
                  icon: widget.isAdding ? Icon(Icons.add) : Icon(Icons.save),
                  onPressed: () async {
                    // put on top so it pops first
                    Navigator.pop(context);

                    if (_formKey.currentState!.validate()) {
                      if (widget.isAdding) {
                        await ExpiscanDB.addEntry(
                            pantryTableName,
                            Pantry(
                                name: _formName.text,
                                picturePath: _formImage.text));
                      } else if (!widget.isAdding) {
                        await ExpiscanDB.updateEntry(
                            pantryTableName,
                            Pantry(
                                id: widget.entry!.id,
                                name: _formName.text,
                                picturePath: _formImage.text));
                      }

                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Saving data...')));
                    }
                  },
                  tooltip: 'Save',
                ),
                Visibility(
                    visible: !widget.isAdding,
                    child: PopupMenuButton(
                      itemBuilder: (BuildContext context) => <PopupMenuEntry>[
                        PopupMenuItem(child: Text('Delete Pantry'), value: 0)
                      ],
                      icon: Icon(Icons.more_vert),
                      onSelected: (value) async {
                        if (value == 0) {
                          var _isDeleted = await showDeleteDialog(
                              context: context,
                              table: pantryTableName,
                              entry: widget.entry!);
                          if (_isDeleted) Navigator.pop(context);
                        }
                      },
                    ))
              ],
            ),
            body: SingleChildScrollView(
                padding: const EdgeInsets.all(25),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                      minHeight: MediaQuery.of(context).size.height - 150),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: <Widget>[
                      ImagePickerFormField(
                        controller: _formImage,
                        height: MediaQuery.of(context).size.height / 2,
                      ),
                      TextFormField(
                        controller: _formName,
                        validator: checkEmpty,
                        decoration: InputDecoration(
                            icon: Icon(Icons.kitchen),
                            labelText: 'Name *',
                            hintText: 'Enter pantry name'),
                      ),
                    ],
                  ),
                ))));
  }
}
