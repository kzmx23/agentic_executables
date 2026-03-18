import '../models/ae_result.dart';
import '../models/know.dart';

abstract interface class AeKnowService {
  Future<AeResult<KnowBuildOutput>> build(final KnowBuildInput input);

  Future<AeResult<KnowShowOutput>> show(final KnowShowInput input);

  Future<AeResult<KnowListOutput>> list(final KnowListInput input);

  Future<AeResult<void>> remove(final KnowRemoveInput input);

  Future<AeResult<KnowBuildOutput>> update(final KnowUpdateInput input);

  Future<AeResult<KnowDiffOutput>> diff(final KnowDiffInput input);
}
