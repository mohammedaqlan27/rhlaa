import os

# حدد هنا مسارات المجلدات التي تريد دمجها
folders_to_scan = ['lib/services', 'lib/models']
output_file = 'all_project_code.txt'

with open(output_file, 'w', encoding='utf-8') as outfile:
    for folder_path in folders_to_scan:
        # التحقق من وجود المجلد لتجنب الأخطاء
        if os.path.exists(folder_path):
            for filename in os.listdir(folder_path):
                if filename.endswith('.dart'):
                    filepath = os.path.join(folder_path, filename)
                    with open(filepath, 'r', encoding='utf-8') as infile:
                        outfile.write(f'\n\n// =============== {filepath} ===============\n\n')
                        outfile.write(infile.read())
        else:
            print(f"تنبيه: المجلد '{folder_path}' غير موجود في المسار المحدد.")

print(f"تم دمج جميع الملفات بنجاح في ملف: {output_file}")