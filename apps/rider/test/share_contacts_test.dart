import 'package:flutter_test/flutter_test.dart';
import 'package:ridema_rider/src/ride/share_contacts.dart';

void main() {
  test('at most 5 contacts', () {
    final m = ShareContactsModel();
    for (var i = 0; i < 5; i++) {
      expect(m.add('C$i', '06123456${i}0'), AddContactResult.added);
    }
    expect(m.isFull, isTrue);
    expect(m.add('Six', '0699999999'), AddContactResult.full);
    expect(m.items.length, 5);
    m.removeAt(0);
    expect(m.add('Six', '0699999999'), AddContactResult.added);
    expect(m.toRecords().length, 5);
  });

  test('validation and duplicates', () {
    final m = ShareContactsModel();
    expect(m.add('', '0612345678'), AddContactResult.invalidName);
    expect(m.add('Ali', '123'), AddContactResult.invalidPhone);
    expect(m.add('Ali', '06 12 34 56 78'), AddContactResult.added);
    expect(m.add('Ali bis', '+212612345678'), AddContactResult.duplicate);
  });

  test('phone normalisation matches the backend', () {
    expect(ShareContactsModel.normalizePhone('0612345678'), '+212612345678');
    expect(ShareContactsModel.normalizePhone('612345678'), '+212612345678');
    expect(ShareContactsModel.normalizePhone('+212 6 12 34 56 78'), '+212612345678');
    expect(ShareContactsModel.normalizePhone('00212712345678'), '+212712345678');
    expect(ShareContactsModel.normalizePhone('+2120612345678'), '+212612345678');
    expect(ShareContactsModel.normalizePhone('+33612345678'), '+33612345678');
    expect(ShareContactsModel.normalizePhone('+21261234'), isNull);
    expect(ShareContactsModel.normalizePhone('0812345678'), isNull);
  });
}
