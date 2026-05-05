import '../models/ae_result.dart';
import '../models/hub.dart';

abstract interface class AeHubService {
  Future<AeResult<HubInitOutput>> init(final HubInitInput input);

  Future<AeResult<HubStatus>> status(final HubStatusInput input);

  Future<AeResult<HubPullOutput>> pull(final HubPullInput input);

  Future<AeResult<HubPushOutput>> push(final HubPushInput input);
}
