import 'package:expiscan/service/database_service.dart';
import 'package:expiscan/screens/settings_page.dart';
import 'package:expiscan/service/notification_service.dart';
import 'package:expiscan/widgets.dart';
import 'package:expiscan/constants/constants.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// easy date to string vice versa converter.
String _dateToString(DateTime date) => DateFormat('d MMMM y').format(date);

class ItemPage extends StatefulWidget {
  final int pantryFilterId;

  ItemPage({this.pantryFilterId = 0});
  @override
  _ItemPageState createState() => _ItemPageState();
}

class _ItemPageState extends State<ItemPage> {
  _showNoteDialog(String itemName, String note) {
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
              title: Text(itemName),
              content: Text(note),
              actions: [
                TextButton(
                    onPressed: Navigator.of(context).pop, child: Text('CLOSE'))
              ],
            ));
  }

  _subtitle(Food entry) {
    return FutureBuilder(
        future: ExpiscanDB.getEntryFromId(pantryTableName, entry.pantryId),
        builder: (BuildContext context, AsyncSnapshot snapshot) {
          if (snapshot.hasData) {
            return Text(
              '${snapshot.data.name}\n' +
                  (entry.isBestBefore == 1 ? 'Best before' : 'Use by') +
                  ': ${_dateToString(entry.expiryDate)}',
              style: TextStyle(height: 1.5),
            );
          } else {
            return Text('Loading...');
          }
        });
  }

  void _insertAllHeader(List list) {
    var textColor = Colors.white;
    var today =
        DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    // Expired
    _insertHeader(
        list: list,
        index: list.indexWhere((element) {
          if (element is Food) {
            return element.expiryDate.isAfter(DateTime(2000)) &&
                element.expiryDate.isBefore(today);
          }
          return false;
        }),
        leading: Icon(Icons.delete_rounded, color: textColor),
        title: 'Expired Items',
        style: TextStyle(color: textColor, fontSize: 16),
        color: Colors.grey[600]!);
    // Expire today
    _insertHeader(
        list: list,
        index: list.indexWhere((element) {
          if (element is Food) {
            return (element.expiryDate.isAfter(today) ||
                    element.expiryDate.isAtSameMomentAs(today)) &&
                element.expiryDate.isBefore(today.add(Duration(days: 1)));
          }
          return false;
        }),
        leading: Icon(Icons.report_gmailerrorred_rounded, color: textColor),
        title: 'Expire today (${DateFormat('yMMMd').format(DateTime.now())})',
        style: TextStyle(color: textColor, fontSize: 16),
        color: Colors.red[400]!);
    // 3 days
    _insertHeader(
        list: list,
        index: list.indexWhere((element) {
          if (element is Food) {
            return (element.expiryDate.isAfter(today.add(Duration(days: 1))) ||
                    element.expiryDate
                        .isAtSameMomentAs(today.add(Duration(days: 1)))) &&
                element.expiryDate.isBefore(today.add(Duration(days: 3)));
          }
          return false;
        }),
        leading: Icon(Icons.warning_amber_rounded, color: textColor),
        title: 'Expire in less than 3 days',
        style: TextStyle(color: textColor, fontSize: 16),
        color: Colors.orange);
    // 7 days
    _insertHeader(
        list: list,
        index: list.indexWhere((element) {
          if (element is Food) {
            return element.expiryDate.isAfter(today.add(Duration(days: 3))) &&
                element.expiryDate.isBefore(today.add(Duration(days: 7)));
          }
          return false;
        }),
        leading: Icon(Icons.error_outline, color: Colors.black),
        title: 'Expire in less than 7 days',
        style: TextStyle(color: Colors.black, fontSize: 16),
        color: Colors.yellow[400]!);
    // > 7 days
    _insertHeader(
        list: list,
        index: list.indexWhere((element) {
          if (element is Food) {
            return element.expiryDate.isAfter(today.add(Duration(days: 7)));
          }
          return false;
        }),
        leading: Icon(Icons.check_circle_outline_rounded, color: textColor),
        title: 'Good Items',
        style: TextStyle(color: textColor, fontSize: 16),
        color: Colors.green[400]!);
  }

  void _insertHeader(
      {required List list,
      required int index,
      Widget? leading,
      required String title,
      TextStyle? style,
      Color color = Colors.grey}) {
    var item = {
      'leading': leading,
      'title': title,
      'color': color,
      'style': style,
      'isNotItem': true
    };

    if (index != -1) list.insert(index, item);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
        future: widget.pantryFilterId != 0
            ? ExpiscanDB.getEntries(foodTableName, widget.pantryFilterId)
            : ExpiscanDB.getEntries(foodTableName),
        builder: (BuildContext context, AsyncSnapshot<dynamic> itemsList) {
          if (itemsList.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (itemsList.connectionState == ConnectionState.done &&
              itemsList.hasData &&
              itemsList.data.isNotEmpty) {
            // Sort date expiring soon
            itemsList.data.sort((a, b) {
              return a.expiryDate!.compareTo(b.expiryDate!) as int;
            });

            _insertAllHeader(itemsList.data);

            return ListView.separated(
                padding: const EdgeInsets.only(bottom: 50),
                itemCount: itemsList.data.length,
                separatorBuilder: (BuildContext context, int index) {
                  return Divider(
                    height: 1,
                  );
                },
                itemBuilder: (BuildContext context, int index) {
                  var entry = itemsList.data[index];
                  if (entry is! Food) {
                    return ListTile(
                      contentPadding: EdgeInsets.symmetric(horizontal: 25),
                      // contentPadding: EdgeInsets.fromLTRB(10, 5, 10, 5),
                      dense: true,
                      leading: entry['leading'],
                      title: Text(entry['title'], style: entry['style']),
                      minLeadingWidth: 25,
                      tileColor: entry['color'],
                    );
                  } else {
                    return ListTile(
                        contentPadding: EdgeInsets.fromLTRB(10, 5, 10, 5),
                        isThreeLine: true,
                        horizontalTitleGap: 15,
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(5),
                          child: FractionallySizedBox(
                            widthFactor: 0.25,
                            heightFactor: 1,
                            child: SmartImageHandler(
                                imagePath: entry.picturePath, iconSize: 35),
                          ),
                        ),
                        title: Text(
                          entry.name +
                              (showDatabaseEntriesId
                                  ? ' (ID: ${entry.id.toString()})'
                                  : ''),
                          style: entry.expiryDate.isBefore(DateTime(
                                  DateTime.now().year,
                                  DateTime.now().month,
                                  DateTime.now().day))
                              ? TextStyle(
                                  color: Colors.red,
                                  decoration: TextDecoration.lineThrough,
                                )
                              : null,
                        ),
                        subtitle: _subtitle(entry),
                        trailing: Visibility(
                          visible: entry.note.isNotEmpty ? true : false,
                          child: TextButton(
                            child: Icon(Icons.notes),
                            onPressed: () {
                              _showNoteDialog(entry.name, entry.note);
                            },
                          ),
                        ),
                        onTap: () async {
                          await Navigator.push(context,
                              MaterialPageRoute(builder: (context) {
                            return ItemDetailPage(
                                isAdding: false, entry: entry);
                          }));
                          setState(() {});
                        });
                  }
                });
          } else {
            return EmptyListPage(
              phrase: 'Food',
            );
          }
        });
  }
}

class ItemDetailPage extends StatefulWidget {
  final bool isAdding;
  final Food? entry;

  ItemDetailPage({required this.isAdding, this.entry});

  @override
  _ItemDetailPageState createState() => _ItemDetailPageState();
}

class _ItemDetailPageState extends State<ItemDetailPage> {
  final _formKey = GlobalKey<FormState>();
  final _formName = TextEditingController();
  final _formImage = TextEditingController();
  final _formExpiryDateController = TextEditingController();
  late DateTime _formExpiryDate;
  late int _formExpiryType;
  final _formNote = TextEditingController();
  int _formPantryId = 1;
  late DateTime _firstPickerDate;

  @override
  void initState() {
    super.initState();
    if (widget.isAdding) {
      _firstPickerDate = DateTime.now();
      _formExpiryDate = DateTime.now();
      _formExpiryType = 0;
    } else {
      _formName.text = widget.entry!.name;
      _formImage.text = widget.entry!.picturePath;
      _formExpiryDate = widget.entry!.expiryDate;
      _formExpiryType = widget.entry!.isBestBefore;
      _formNote.text = widget.entry!.note;
      _formPantryId = widget.entry!.pantryId;
      _firstPickerDate = _formExpiryDate.isBefore(DateTime.now())
          ? _formExpiryDate
          : DateTime.now();
    }
    _formExpiryDateController.text = _dateToString(_formExpiryDate);
  }

  void _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _formExpiryDate,
      firstDate: _firstPickerDate,
      lastDate: DateTime(_firstPickerDate.year + 10),
    );

    if (picked != null && picked != _formExpiryDate)
      setState(() {
        _formExpiryDate = picked;
        _formExpiryDateController.text = _dateToString(picked);
      });
  }

  @override
  Widget build(BuildContext context) {
    return Form(
        key: _formKey,
        child: Scaffold(
            appBar: AppBar(
              title: widget.isAdding
                  ? Text('Add Food Item')
                  : Text('Edit Food Item'),
              actions: <Widget>[
                IconButton(
                  icon: widget.isAdding ? Icon(Icons.add) : Icon(Icons.save),
                  onPressed: () async {
                    // Validate returns true if the form is valid, or false otherwise.
                    if (_formKey.currentState!.validate()) {
                      // pop first so it won't double click
                      Navigator.pop(context);

                      if (widget.isAdding) {
                        await ExpiscanDB.addEntry(
                            foodTableName,
                            Food(
                                name: _formName.text,
                                picturePath: _formImage.text,
                                expiryDate: _formExpiryDate,
                                isBestBefore: _formExpiryType,
                                note: _formNote.text,
                                pantryId: _formPantryId));
                      } else if (!widget.isAdding) {
                        await ExpiscanDB.updateEntry(
                            foodTableName,
                            Food(
                                id: widget.entry!.id,
                                name: _formName.text,
                                picturePath: _formImage.text,
                                expiryDate: _formExpiryDate,
                                isBestBefore: _formExpiryType,
                                note: _formNote.text,
                                pantryId: _formPantryId));
                      }
                      await initNotificationService();

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
                        PopupMenuItem(child: Text('Delete Food Item'), value: 0)
                      ],
                      icon: Icon(Icons.more_vert),
                      onSelected: (value) async {
                        if (value == 0) {
                          var _isDeleted = await showDeleteDialog(
                              context: context,
                              table: foodTableName,
                              entry: widget.entry!);
                          if (_isDeleted) {
                            await initNotificationService();
                            Navigator.pop(context);
                          }
                        }
                      },
                    ))
              ],
            ),
            body: SingleChildScrollView(
                padding: const EdgeInsets.all(25),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                      minHeight: MediaQuery.of(context).size.height - 75),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: <Widget>[
                      ImagePickerFormField(
                        controller: _formImage,
                        height: MediaQuery.of(context).size.height / 3,
                      ),
                      TextFormField(
                        controller: _formName,
                        validator: (value) => checkEmpty(value),
                        decoration: InputDecoration(
                            icon: Icon(Icons.fastfood),
                            labelText: 'Name *',
                            hintText: 'Enter food item name'),
                      ),
                      TextFormField(
                        readOnly: true,
                        controller: _formExpiryDateController,
                        decoration: InputDecoration(
                            icon: Icon(Icons.today),
                            labelText: 'Expiry Date *',
                            hintText: 'Enter date'),
                        onTap: () => _selectDate(context),
                      ),
                      DropdownButtonFormField(
                        value: _formExpiryType == 0 ? 'Use By' : 'Best Before',
                        onChanged: (String? value) {
                          setState(() {
                            _formExpiryType = value == 'Use By' ? 0 : 1;
                          });
                        },
                        items: <String>['Use By', 'Best Before']
                            .map<DropdownMenuItem<String>>((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                        decoration: InputDecoration(
                            icon: Icon(Icons.compare),
                            labelText: 'Expiry Date Type',
                            hintText: 'Pick Expiry Date Type'),
                      ),
                      TextFormField(
                        controller: _formNote,
                        decoration: InputDecoration(
                            icon: Icon(Icons.note),
                            labelText: 'Note',
                            hintText: 'Enter a note'),
                      ),
                      FutureBuilder(
                          future: ExpiscanDB.getEntries(pantryTableName),
                          builder:
                              (BuildContext context, AsyncSnapshot snapshot) {
                            if (snapshot.hasData && snapshot.data.isNotEmpty) {
                              return DropdownButtonFormField(
                                value: _formPantryId,
                                // hint: Text(''),
                                onChanged: (value) {
                                  setState(() {
                                    _formPantryId = value as int;
                                  });
                                },
                                items: snapshot.data
                                    .map<DropdownMenuItem<int>>((pantry) {
                                  return DropdownMenuItem<int>(
                                    value: pantry.id,
                                    child: Text(pantry.name),
                                  );
                                }).toList(),
                                decoration: InputDecoration(
                                    icon: Icon(Icons.kitchen),
                                    labelText: 'Pantry',
                                    hintText: 'Pick Pantry (Location)'),
                              );
                            } else {
                              return DropdownButtonFormField(
                                validator: (String? value) => checkEmpty(value),
                                items: null,
                                decoration: InputDecoration(
                                    icon: Icon(Icons.kitchen),
                                    labelText:
                                        '(You haven\'t added a Pantry yet.)',
                                    hintText: 'Pick Pantry (Location)'),
                              );
                            }
                          })
                    ],
                  ),
                ))));
  }
}
