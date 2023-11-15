import * as MediaLibrary from 'expo-media-library';
import { PixelRatio } from 'react-native';
import ViewShot, { captureRef } from 'react-native-view-shot';

type CaptureImageProps = {
  desiredSize: number;
  desiredAspectRatio: number;
  viewShotRef: React.RefObject<ViewShot>;
};

const pixelRatio = PixelRatio.get();

export const captureImage = ({
  desiredSize,
  desiredAspectRatio,
  viewShotRef
}: CaptureImageProps) => {
  let height = desiredSize;
  let width = height * desiredAspectRatio;

  if (desiredAspectRatio > 1) {
    width = desiredSize;
    height = width / desiredAspectRatio;
  }

  captureRef(viewShotRef, {
    format: 'jpg',
    quality: 1.0,
    height: height / pixelRatio,
    width: width / pixelRatio
  }).then(
    (uri) => {
      MediaLibrary.saveToLibraryAsync(uri);
    },
    (error) => console.error('Oops, snapshot failed', error)
  );
};

export function getShortenedFileName(fileName: string | null | undefined) {
  return fileName !== undefined && fileName !== null
    ? fileName.length > 12
      ? `${fileName?.split('.')[0].substring(0, 10)}...`
      : fileName?.split('.')[0]
    : 'Image';
}
