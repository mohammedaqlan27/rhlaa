import 'dart:io';

void main() {
  var root = Directory('lib');
  if (!root.existsSync()) {
    print('المجلد lib غير موجود');
    return;
  }
  
  void printTree(Directory dir, [String prefix = '']) {
    var files = dir.listSync();
    for (var i = 0; i < files.length; i++) {
      var file = files[i];
      var isLast = i == files.length - 1;
      var connector = isLast ? '└── ' : '├── ';
      var newPrefix = prefix + (isLast ? '    ' : '│   ');
      
      if (file is Directory) {
        print('$prefix$connector${file.path.split(Platform.pathSeparator).last}/');
        printTree(file, newPrefix);
      } else if (file is File && file.path.endsWith('.dart')) {
        print('$prefix$connector${file.path.split(Platform.pathSeparator).last}');
      }
    }
  }
  
  print('lib/');
  printTree(root);
}