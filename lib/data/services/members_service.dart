import 'api_service.dart';

/// A person a dig site is shared with.
class DigSiteMember {
  const DigSiteMember({
    required this.userId,
    required this.email,
    required this.joinedAt,
  });

  final String userId;
  final String email;
  final DateTime joinedAt;

  factory DigSiteMember.fromJson(Map<String, dynamic> json) => DigSiteMember(
    userId: json['user_id'] as String,
    email: json['email'] as String,
    joinedAt:
        DateTime.tryParse(json['joined_at'] as String? ?? '') ?? DateTime.now(),
  );
}

/// Why an invitation could not be completed.
///
/// A typed reason rather than a raw HTTP error: the person reading it is an
/// archaeologist in a tent, and "404" tells them nothing about what to do
/// next.
enum InviteFailure {
  /// No account uses that email address.
  unknownEmail,

  /// Only the dig site's owner may change who it is shared with.
  notOwner,

  /// The invitation never reached the server.
  ///
  /// Membership is the one part of collaboration that genuinely cannot work
  /// offline -- there is no way to agree with the server about a new member
  /// without reaching it.
  offline,

  /// Anything else.
  unknown,
}

class InviteException implements Exception {
  const InviteException(this.reason);

  final InviteFailure reason;

  @override
  String toString() => 'InviteException($reason)';
}

/// Membership of shared dig sites.
///
/// Every call here needs a connection. That is inherent, not an oversight:
/// it happens once in camp, and everything afterwards works in the field.
class MembersService {
  const MembersService(this._api);

  final ApiService _api;

  Future<List<DigSiteMember>> listMembers(String folderId) async {
    final response = await _api.get('/folders/$folderId/members');
    return (response as List)
        .map((e) => DigSiteMember.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<DigSiteMember> invite(String folderId, String email) async {
    try {
      final response = await _api.post('/folders/$folderId/members', {
        'email': email,
      });
      return DigSiteMember.fromJson(response as Map<String, dynamic>);
    } on Exception catch (error) {
      throw InviteException(_classify(error));
    }
  }

  Future<void> revoke(String folderId, String userId) =>
      _api.delete('/folders/$folderId/members/$userId');

  /// Maps a transport-level failure onto something worth showing a person.
  ///
  /// Matches on the status code in the message because `ApiService` surfaces
  /// failures as plain exceptions; if it ever grows typed errors, this should
  /// switch to those rather than gaining more string matching.
  InviteFailure _classify(Exception error) {
    final message = error.toString();
    if (message.contains('404')) return InviteFailure.unknownEmail;
    if (message.contains('403')) return InviteFailure.notOwner;
    if (message.contains('SocketException') ||
        message.contains('Connection') ||
        message.contains('TimeoutException')) {
      return InviteFailure.offline;
    }
    return InviteFailure.unknown;
  }
}
