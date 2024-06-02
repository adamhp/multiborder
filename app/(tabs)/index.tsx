import FontAwesome from '@expo/vector-icons/FontAwesome';
import * as ImagePicker from 'expo-image-picker';
import * as MediaLibrary from 'expo-media-library';
import { useEffect, useState } from 'react';
import { ActivityIndicator, Pressable, View } from 'react-native';
import { useRecoilState } from 'recoil';
import { ImagesScrollView } from '../../components/ImageScrollView';
import {
  ImageThumbnail,
  ImageThumbnailPost
} from '../../components/ImageThumbnail';
import {
  captureFunctionsState,
  imagesState,
  loadSettings,
  settingsState
} from '../../lib/state';
import { PageContainer } from './_layout';
import _ from 'lodash';

function alertNeedsPermissions() {
  alert(
    "Multiborder needs media library access to select photos and save edited photos. Please enable this permission in your device's settings."
  );
}
export default function SelectScreen() {
  const [imagePickerPermission, requestImagePickerPermission] =
    ImagePicker.useMediaLibraryPermissions();
  const [mediaLibraryPermission, requestMediaLibraryPermission] =
    MediaLibrary.usePermissions();
  const [settings, setSettings] = useRecoilState(settingsState);
  const [images, setImages] = useRecoilState(imagesState);
  const [loading, setLoading] = useState<boolean>(false);
  const [captureFunctions, setCaptureFunctions] = useRecoilState(
    captureFunctionsState
  );

  useEffect(() => {
    loadSettings().then((settings) => {
      setSettings(settings);
    });
  }, []);

  const pickImage = async () => {
    if (!imagePickerPermission?.granted) {
      if (imagePickerPermission?.canAskAgain) {
        const result = await requestImagePickerPermission();
        if (!result.granted) {
          alertNeedsPermissions();
        }
      } else {
        alertNeedsPermissions;
      }
    }
    if (!mediaLibraryPermission?.granted) {
      if (mediaLibraryPermission?.canAskAgain) {
        const result = await requestMediaLibraryPermission();
        if (!result.granted) {
          alertNeedsPermissions();
        }
      } else {
        alertNeedsPermissions;
      }
    }

    setTimeout(() => {
      setLoading(true);
    }, 250);

    let result = await ImagePicker.launchImageLibraryAsync({
      mediaTypes: ImagePicker.MediaTypeOptions.Images,
      allowsMultipleSelection: true,
      quality: 1
    });

    if (!result.canceled) {
      setImages(result.assets);
    }

    setLoading(false);
  };

  const clearImages = async () => {
    setCaptureFunctions({});
    setImages([]);
  };

  const removeImage = async (image: ImagePicker.ImagePickerAsset) => {
    setCaptureFunctions((state) => _.omit(state, image.uri));
    setImages((state) => [...state.filter((i) => i.uri !== image.uri)]);
  };

  useEffect(() => {}, [settings]);

  return (
    <PageContainer>
      <ImagesContainer>
        {loading ? (
          <ActivityIndicator size="large" />
        ) : (
          <ImagesScrollView
            renderImage={(item) => (
              <View key={item.uri} className="mx-3">
                <ImageThumbnail item={item} removeImage={removeImage} />
              </View>
            )}
            images={images}
          />
        )}
      </ImagesContainer>
      <ImagesContainer>
        <ImagesScrollView
          renderImage={(item) => (
            <View key={item.uri} className="mx-3">
              <ImageThumbnailPost
                borderSize={settings.borderSize}
                item={item}
              />
            </View>
          )}
          images={images}
        />
      </ImagesContainer>
      <PickerButtons
        images={images}
        pickImage={pickImage}
        clearImages={clearImages}
      />
    </PageContainer>
  );
}

type PickerButtonsProps = {
  images: ImagePicker.ImagePickerAsset[];
  pickImage: () => Promise<void>;
  clearImages: () => Promise<void>;
};

function PickerButtons({ images, pickImage, clearImages }: PickerButtonsProps) {
  return (
    <View className="flex-1 h-1/5 justify-center items-center">
      {images.length === 0 ? (
        <Pressable
          accessible={true}
          accessibilityLabel="Select images"
          accessibilityHint="Opens photo roll to select images"
          accessibilityRole="spinbutton"
          className="rounded-full bg-zinc-700 w-20 h-20 flex justify-center items-center active:bg-zinc-800"
          onPress={pickImage}
        >
          {({ pressed }) => (
            <FontAwesome name="plus-circle" size={40} color="white" />
          )}
        </Pressable>
      ) : (
        <Pressable
          accessible={true}
          accessibilityLabel="Clear images"
          accessibilityHint="Clears all currently selected images"
          accessibilityRole="button"
          className="rounded-full bg-zinc-700 w-20 h-20 flex justify-center items-center active:bg-zinc-800"
          onPress={clearImages}
        >
          {({ pressed }) => (
            <FontAwesome name="close" size={40} color="white" />
          )}
        </Pressable>
      )}
    </View>
  );
}

export function ImagesContainer({
  children
}: React.ComponentPropsWithoutRef<typeof View>) {
  return (
    <View className="flex h-2/5 justify-center items-center m-2 p-2">
      {children}
    </View>
  );
}
