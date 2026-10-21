allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// نقل مجلد build إلى مستوى أعلى (كما في مشروعك)
val newBuildDir = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

// --- الإصلاح الذكي لخطأ Namespace للمكتبات القديمة ---
// نتحقق من امتداد "android" لكل مشروع فرعي بعد التقييم، ونضيف خاصية "namespace"
// على مستوى المشروع (extraProperties) إن لم تكن موجودة.
// نستخدم project.hasProperty / project.extensions.extraProperties بدلاً من استدعاء
// property/setProperty على كائن android مباشرة (هذا يسبب أخطاء في Kotlin DSL).
subprojects {
    afterEvaluate {
        // داخل هذا الـ closure، الـ receiver هو Project (أي "this")
        val p = this

        // إذا المشروع يحتوي امتداد android (مكتبات Android أو تطبيق)
        if (p.extensions.findByName("android") != null) {
            // إذا لم تُعرّف خاصية "namespace" على مستوى المشروع، نضيفها كـ extra property
            if (!p.hasProperty("namespace")) {
                p.extensions.extraProperties["namespace"] = p.group.toString()
            } else {
                // إذا كانت موجودة ولكن فارغة أو null، نضع قيمة افتراضية
                val ns = try {
                    val prop = p.property("namespace")
                    prop?.toString()
                } catch (e: Exception) {
                    null
                }
                if (ns.isNullOrBlank()) {
                    p.extensions.extraProperties["namespace"] = p.group.toString()
                }
            }
        }
    }
}

// التأكد من أن تقييم المشاريع الفرعية يعتمد على :app (كما في مشروعك)
subprojects {
    project.evaluationDependsOn(":app")
}

// مهمة clean
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
