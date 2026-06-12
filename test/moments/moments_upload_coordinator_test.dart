import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:zztherapy/features/moments/models/moments_models.dart';
import 'package:zztherapy/features/moments/services/moments_upload_coordinator.dart';

void main() {
  group('MomentsUploadCoordinator.isVideo', () {
    test('detects video mime types', () {
      expect(
        MomentsUploadCoordinator.isVideo(_fakeFile(mimeType: 'video/mp4')),
        isTrue,
      );
    });

    test('detects video extensions when mime is missing', () {
      expect(
        MomentsUploadCoordinator.isVideo(_fakeFile(path: '/tmp/clip.MOV')),
        isTrue,
      );
    });

    test('treats images as non-video', () {
      expect(
        MomentsUploadCoordinator.isVideo(
          _fakeFile(mimeType: 'image/jpeg', path: '/tmp/photo.jpg'),
        ),
        isFalse,
      );
    });
  });

  group('MomentsUploadCoordinator.classifyMedia', () {
    test('classifies photo and video picks', () {
      expect(
        MomentsUploadCoordinator.classifyMedia(_fakeFile(path: '/tmp/a.png')).kind,
        MomentsMediaKind.photo,
      );
      expect(
        MomentsUploadCoordinator.classifyMedia(_fakeFile(path: '/tmp/a.mp4')).kind,
        MomentsMediaKind.video,
      );
    });
  });
}

XFile _fakeFile({String path = '/tmp/file.bin', String? mimeType}) {
  return XFile(path, mimeType: mimeType);
}
