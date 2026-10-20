import 'dart:async';
import 'dart:io';

import 'package:matrix/matrix.dart';

/// Maps raw technical exceptions to clear, non-technical Russian messages for end users.
class FriendlyErrorMapper {
  static String toUserMessage(Object error) {
    if (error is FormatException) {
      return error.message;
    }
    if (error is MatrixException) {
      switch (error.errcode) {
        case 'M_FORBIDDEN':
          return 'Неверное имя пользователя или пароль. Проверьте введённые данные и попробуйте снова.';
        case 'M_USER_DEACTIVATED':
          return 'Этот аккаунт отключён администратором семьи.';
        case 'M_LIMIT_EXCEEDED':
          return 'Слишком много попыток. Пожалуйста, подождите минуту и попробуйте снова.';
        case 'M_NOT_FOUND':
          return 'Участник или беседа не найдены.';
        case 'M_BAD_JSON':
        case 'M_INVALID_PARAM':
          return 'Проверьте правильность введённых данных.';
        default:
          return 'Сервер временно отклонил запрос. Попробуйте ещё раз чуть позже.';
      }
    }
    if (error is HandshakeException || error is TlsException) {
      return 'Не удалось установить защищённое соединение. Проверьте дату и время на устройстве.';
    }
    if (error is SocketException) {
      return 'Нет подключения к интернету. Проверьте мобильную сеть или Wi-Fi.';
    }
    if (error is TimeoutException) {
      return 'Сервер отвечает слишком долго. Проверьте качество интернет-соединения.';
    }
    final text = error.toString().toLowerCase();
    if (text.contains('m_forbidden') || text.contains('invalid username or password')) {
      return 'Неверное имя пользователя или пароль.';
    }
    if (text.contains('socketexception') ||
        text.contains('failed host lookup') ||
        text.contains('network is unreachable') ||
        text.contains('connection refused')) {
      return 'Нет связи с сервером. Проверьте подключение к интернету.';
    }
    if (text.contains('invalid recovery key') ||
        text.contains('decryption') ||
        text.contains('passphrase')) {
      return 'Неверный код восстановления. Проверьте введённые символы.';
    }
    return 'Не удалось выполнить действие. Проверьте подключение к сети и попробуйте снова.';
  }
}
