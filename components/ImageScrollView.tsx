import * as ImagePicker from 'expo-image-picker';
import { ScrollView } from 'react-native-gesture-handler';

export const ImagesScrollView = ({
  images,
  renderImage,
  className
}: {
  images: ImagePicker.ImagePickerAsset[];
  renderImage: (image: ImagePicker.ImagePickerAsset) => JSX.Element;
  className?: string;
}) => {
  return (
    <ScrollView className={className} horizontal={true} decelerationRate="fast">
      {images.map((item) => renderImage(item))}
    </ScrollView>
  );
};
