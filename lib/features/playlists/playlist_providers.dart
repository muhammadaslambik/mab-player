import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/playlist_repo.dart';
import '../../providers.dart';

final playlistRepoProvider =
    Provider((ref) => PlaylistRepo(ref.read(storeProvider)));
