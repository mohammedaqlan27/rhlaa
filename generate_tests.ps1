# generate_tests.ps1 (مصحح)
$srcDir = "lib/services"
$testDir = "test/services"
$packageName = "rhlaa"   # غيّر إذا اختلف اسم الحزمة في pubspec.yaml

if (-not (Test-Path $srcDir)) {
  Write-Host "Source directory not found: $srcDir" -ForegroundColor Red
  exit 1
}

if (-not (Test-Path $testDir)) {
  New-Item -ItemType Directory -Path $testDir | Out-Null
}

function ToClassName($name) {
  if ($name.Length -eq 0) { return $name }
  return ($name.Substring(0,1).ToUpper() + $name.Substring(1))
}

Get-ChildItem -Path $srcDir -Filter *.dart | ForEach-Object {
  $base = $_.BaseName
  $className = ToClassName $base
  $testfile = Join-Path $testDir "${base}_test.dart"

  # قالب بسيط وآمن مع متغيرات PowerShell
  $content = @"
/// test/services/${base}_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:$packageName/services/${base}.dart';

// TODO: عدّل Mock/Dependency حسب كود ${base}.dart
class MockDependency extends Mock {}

void main() {
  late ${className} service;
  late MockDependency mockDep;

  setUp(() {
    mockDep = MockDependency();
    try {
      service = ${className}(mockDep);
    } catch (e) {
      service = ${className}();
    }
  });

  test('returns expected result on success for ${base}', () async {
    // TODO: استبدل هذا بالتحقق الفعلي من دوال ${base}
    expect(1 + 1, equals(2));
  });

  test('handles failure for ${base}', () async {
    // TODO: محاكاة خطأ من التبعية وتحقق من المعالجة
    expect(() => throw Exception('simulated'), throwsException);
  });
}
"@

  if (Test-Path $testfile) {
    Write-Host "Exists $testfile, skipping"
  } else {
    $content | Out-File -FilePath $testfile -Encoding utf8
    Write-Host "Created $testfile"
  }
}
