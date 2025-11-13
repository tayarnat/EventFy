/// Serviço responsável por orquestrar Push Notifications em dispositivos.
///
/// IMPORTANTE: Para push verdadeiro (background, app fechado), será necessário
/// integrar um provedor como Firebase Cloud Messaging (FCM) ou OneSignal.
/// Este arquivo prepara a estrutura e orientação para a integração sem quebrar
/// a build atual. A implementação real pode ser feita numa segunda etapa.
class PushNotificationsService {
  static final PushNotificationsService _instance = PushNotificationsService._internal();
  factory PushNotificationsService() => _instance;
  PushNotificationsService._internal();

  static PushNotificationsService get instance => _instance;

  /// Inicializa o serviço de push. Nesta etapa, apenas um placeholder.
  Future<void> initialize() async {
    // Passos da próxima etapa (documentados):
    // 1) Adicionar dependências:
    //    - firebase_core
    //    - firebase_messaging
    //    - flutter_local_notifications (opcional, para mostrar no foreground)
    // 2) Executar `flutterfire configure` e ajustar AndroidManifest/Info.plist.
    // 3) No primeiro login, registrar device token em uma tabela `user_devices` no Supabase.
    // 4) No backend (Supabase Edge Functions), enviar push usando FCM para tokens dos usuários.
    // 5) No app, implementar handlers onMessage/onBackgroundMessage para salvar a notificação
    //    na tabela `notifications` (ou local) e navegar (deep link) ao clicar.
  }
}