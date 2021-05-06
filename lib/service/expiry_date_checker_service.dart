import 'package:intl/intl.dart';

bool isExpiryDate(String text) {
  final String day = r'(0[1-9]|1[0-9]|2[0-9]|3[01])?';
  final String month =
      r'((0[0-9]|1[0-2])|(JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DES))';
  final String year = r'((20)?[2-9][0-9])?';
  text = text.trim().toUpperCase().replaceAll(RegExp(r'-*\/*\.* *'), '');
  if (!text.contains(RegExp(r'^' + day + month + year + r'$'))) return false;
  if (text.length < 4) return false;
  return true;
}

DateTime parseDate(String dateString) {
  final String month = r'JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DES';
  final RegExp numOnlyRegex = RegExp(r'^[0-9]*$');
  final RegExp dateFirstRegex = RegExp(r'^[0-3][0-9]');
  final RegExp monthNameFirstRegex = RegExp(r'^(' + month + r')');
  try {
    DateFormat dateFormat = DateFormat();

    // ddmmyyyy
    if (dateString.length == 8 && dateString.contains(numOnlyRegex)) {
      return DateTime(
          int.parse(dateString.substring(4, 8)),
          int.parse(dateString.substring(2, 4)),
          int.parse(dateString.substring(0, 2)));
    } else if (dateString.length == 6 && dateString.contains(numOnlyRegex)) {
      // mmyyyy
      if (dateString[2] == '2')
        return DateTime(int.parse(dateString.substring(2, 6)),
                int.parse(dateString.substring(0, 2)))
            .add(Duration());

      // ddmmyy
      return DateTime(
          int.parse('20' + dateString.substring(4, 6)),
          int.parse(dateString.substring(2, 4)),
          int.parse(dateString.substring(0, 2)));
    } else if (dateString.contains(monthNameFirstRegex) &&
        dateString.contains(RegExp(month))) {
      // FEB 22
      if (dateString.length == 5) {
        dateString =
            dateString.substring(0, 3) + '20' + dateString.substring(3, 5);
      }
      // FEB 2022
      dateFormat = DateFormat('MMMy');
    }

    // 01 MAY
    else if (dateString.contains(dateFirstRegex) &&
        dateString.contains(RegExp(month))) {
      if (dateString.length == 5) {
        dateString += DateTime.now().year.toString();
      }
      // 01 MAY 21
      else if (dateString.length == 7) {
        dateString =
            dateString.substring(0, 5) + '20' + dateString.substring(5, 7);
      }

      // 01 MAY 2021
      dateFormat = DateFormat('ddMMMy');
    }

    // print(dateFormat.pattern);
    return dateFormat.parseLoose(dateString);
  } catch (e) {
    return DateTime.now();
  }
}
