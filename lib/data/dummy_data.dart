import 'package:call_tracker/data/models.dart';

const List<Student> dummyStudents = [
  Student(
    id: '1',
    name: 'Lina Djaafri',
    phone: '+213 550 12 34 56',
    level: 'A1',
    parentName: 'Karim Djaafri',
    studentId: '#LI-2024-101',
  ),
  Student(
    id: '2',
    name: 'Mehdi Hamidouche',
    phone: '+213782061943',
    level: 'A2',
    parentName: 'Yacine Hamidouche',
    studentId: '#LI-2024-102',
  ),
  Student(
    id: '3',
    name: 'Sara Boukhors',
    phone: '+213 772 34 56 78',
    level: 'B1',
    parentName: 'Amine Boukhors',
    studentId: '#LI-2024-103',
  ),
  Student(
    id: '4',
    name: 'Amine Mansouri',
    phone: '+213 555 45 67 89',
    level: 'A1',
    parentName: 'Nadia Mansouri',
    studentId: '#LI-2024-104',
  ),
  Student(
    id: '5',
    name: 'Meriem Belkacem',
    phone: '+213 660 56 78 90',
    level: 'B2',
    parentName: 'Rachid Belkacem',
    studentId: '#LI-2024-105',
  ),
  Student(
    id: '6',
    name: 'Yacine Haddad',
    phone: '+213 770 67 89 01',
    level: 'A2',
    parentName: 'Samir Haddad',
    studentId: '#LI-2024-106',
  ),
  Student(
    id: '7',
    name: 'Amine Chaalal',
    phone: '+213 555 123 456',
    level: 'B2',
    parentName: 'Kamel Chaalal',
    studentId: '#LI-2024-882',
  ),
];

const List<Group> dummyGroups = [
  Group(name: 'Ramzi C1', studentCount: 24, studentIds: ['1', '2']),
  Group(name: 'Karim A2', studentCount: 45, studentIds: ['2', '6']),
  Group(name: 'Youssef B1', studentCount: 15, studentIds: ['3']),
  Group(name: 'Bourhane B2', studentCount: 12, studentIds: ['5', '7']),
  Group(name: 'Samy A1', studentCount: 18, studentIds: ['1', '4']),
  Group(name: 'Ayoub C1', studentCount: 20, studentIds: ['3', '5']),
  Group(name: 'Amina A1', studentCount: 22, studentIds: ['4']),
];
