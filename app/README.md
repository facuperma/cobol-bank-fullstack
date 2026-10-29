# App Flutter (Banco COBOL)

App para empleados del banco (cajeros y supervisores), para Android y web. Usa la API REST de [../api](../api), que a su vez usa el núcleo COBOL.

```powershell
flutter build web --base-href /app/                                  # la sirve la API en /app/
flutter build apk --dart-define=API_URL=http://<IP-de-la-PC>:8000    # APK para el celular
flutter test
```

Instalación, pantallas y uso desde el celular: ver el [README principal](../README.md#app-flutter).
