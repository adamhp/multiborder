import * as ImagePicker from 'expo-image-picker';
import { ScrollView } from 'react-native-gesture-handler';
import { Settings } from '../lib/state';

export const ImagesScrollView = ({
  images,
  settings,
  renderImage,
  className
}: {
  images: ImagePicker.ImagePickerAsset[];
  settings: Settings;
  renderImage: (image: ImagePicker.ImagePickerAsset) => JSX.Element;
  className?: string;
}) => {
  const offsets = images.map((image, idx) => {
    if (settings.desiredAspectRatio === -1) {
    }
    if (idx === 0) {
      return 0;
    }
    return (settings.desiredSize * settings.desiredAspectRatio) / 2 + 24;
  });
  console.log({ desiredSize: settings.desiredSize, offsets });
  return (
    <ScrollView
      className={className}
      horizontal={true}
      decelerationRate={0}
      snapToOffsets={offsets}
      // snapToInterval={
      //   settings.desiredSize * settings.desiredAspectRatio + 32
      // }
      snapToAlignment={'center'}
    >
      {images.map((item) => renderImage(item))}
    </ScrollView>
  );
};
