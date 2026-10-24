cd server
node mock-server.js --port 8080 --origin http://localhost:5555
```

Затем клиент — обязательно с фиксированным портом, иначе источник
будет меняться и сервер начнёт отклонять запросы:

flutter pub get
flutter run -d chrome --web-port=5555

Другой адрес сервера задаётся параметром сборки:

flutter run -d chrome --web-port=5555 \
  --dart-define=API_BASE_URL=http://192.168.1.10:8080/api


Учётные записи:
client / client123 / client - только чтение
photographer / photographer123 / photographer - только чтение
manager / manager123 / manager - создание, изменение, логическое и множественное удаление admin / admin123 / admin - все, включая физическое удаление и восстановление 