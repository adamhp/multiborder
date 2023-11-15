import FontAwesome from '@expo/vector-icons/FontAwesome';
import * as ImagePicker from 'expo-image-picker';
import * as MediaLibrary from 'expo-media-library';
import {
  ActivityIndicator,
  Image,
  PixelRatio,
  Pressable,
  PressableProps,
  Text,
  View
} from 'react-native';

import { useEffect, useRef, useState } from 'react';
import { FlatList } from 'react-native-gesture-handler';
import ViewShot, { captureRef } from 'react-native-view-shot';
import { useRecoilState } from 'recoil';
import { captureFunctionsState, imagesState, settingsState } from '../state';
import { PageContainer } from './_layout';

export default function SelectScreen() {
  const [images, setImages] = useRecoilState(imagesState);
  const [loading, setLoading] = useState<boolean>(false);

  const pickImage = async () => {
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
    setImages([]);
  };

  const removeImage = async (image: ImagePicker.ImagePickerAsset) => {
    setImages((state) => [...state.filter((i) => i.uri !== image.uri)]);
  };

  return (
    <PageContainer>
      <ImagesContainer>
        {loading ? (
          <ActivityIndicator size="large" />
        ) : (
          <FlatList
            horizontal
            data={images}
            renderItem={({ item, index }) => (
              <ImageThumbnail item={item} removeImage={removeImage} />
            )}
          />
        )}
      </ImagesContainer>
      <ImagesContainer>
        <FlatList
          horizontal
          data={images}
          renderItem={({ item, index }) => (
            <ImageThumbnailPost item={item} removeImage={removeImage} />
          )}
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

function ImagesContainer({
  children
}: React.ComponentPropsWithoutRef<typeof View>) {
  return (
    <View className="flex h-2/5 justify-center items-center m-2 p-2">
      {children}
    </View>
  );
}

function ImageButton(props: PressableProps) {
  return (
    <Pressable
      {...props}
      className="absolute top-0 -right-4 z-10 rounded-full bg-zinc-700/50 w-8 h-8 flex justify-center items-center active:bg-zinc-800"
    >
      <FontAwesome name="close" size={20} color="rgb(244 244 245)" />
    </Pressable>
  );
}

function ImageLabel({ children }: { children: React.ReactNode }) {
  return (
    <Text accessibilityRole="text" className="text-xs text-zinc-500 font-space">
      {children}
    </Text>
  );
}

export function ImageThumbnail({
  item,
  removeImage
}: {
  item: ImagePicker.ImagePickerAsset;
  removeImage: (image: ImagePicker.ImagePickerAsset) => void;
}) {
  const aspectRatio = item.width / item.height;
  const maxHeight = 200;
  const height = Math.min(maxHeight, 160 / aspectRatio);
  const width = height * aspectRatio;
  return (
    <View className="items-center flex flex-col mt-2 relative mx-4">
      <ImageLabel>{getShortenedFileName(item.fileName)}</ImageLabel>
      <ImageButton onPress={() => removeImage(item)} />
      <Image
        accessibilityRole="image"
        source={{ uri: item.uri }}
        style={{
          objectFit: 'contain',
          width: width,
          height: height
        }}
      />
    </View>
  );
}

type ResizeProps = {
  ref: React.RefObject<Image>;
  aspectRatio: number;
  desiredSize: number;
};

const resize = ({ ref, aspectRatio, desiredSize }: ResizeProps) => {
  if (!ref.current) return;
};

type CaptureImageProps = {
  desiredSize: number;
  desiredAspectRatio: number;
  viewShotRef: React.RefObject<ViewShot>;
};

const pixelRatio = PixelRatio.get();

const captureImage = ({
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

export function ImageThumbnailPost({
  item,
  borderSize = 5,
  removeImage
}: {
  item: ImagePicker.ImagePickerAsset;
  borderSize?: number;
  removeImage: (image: ImagePicker.ImagePickerAsset) => void;
}) {
  const [settings, setSettings] = useRecoilState(settingsState);
  const [captureFunctions, setCaptureFunctions] = useRecoilState(
    captureFunctionsState
  );
  const viewShotRef = useRef<ViewShot>(null);
  const imageViewRef = useRef<View>(null);
  const imageRef = useRef<Image>(null);

  // Get original aspect ratio
  const aspectRatio = item.width / item.height;

  // Set container size based on desired size and desired aspect ratio
  const containerHeight = settings.desiredSize;
  const containerWidth = settings.desiredSize * settings.desiredAspectRatio;

  // Set image size based on container size and original aspect ratio
  let height = containerHeight - 2 * borderSize;
  let width = height * aspectRatio;

  // If original aspect ratio causes width to be greater than container,
  // use width as long edge and adjust height to match
  if (width > containerWidth - 2 * borderSize) {
    width = containerWidth - 2 * borderSize;
    height = width / aspectRatio;
  }

  useEffect(() => {
    setCaptureFunctions((state) => ({
      ...state,
      [item.uri]: (size: number | 'original') => {
        let desiredSize =
          size === 'original' ? Math.max(item.height, item.width) : size;
        setSettings((state) => ({ ...state, desiredSize }));
        captureImage({
          desiredAspectRatio: settings.desiredAspectRatio,
          desiredSize,
          viewShotRef
        });
        setSettings((state) => ({ ...state, desiredSize: 200 }));
      }
    }));
  }, [settings]);

  return (
    <View className="items-center flex flex-col mt-2 relative mx-4">
      <Text className="text-xs text-zinc-500 font-space">
        {getShortenedFileName(item.fileName)}
      </Text>
      <ViewShot
        style={{
          width: containerWidth,
          height: containerHeight
        }}
        ref={viewShotRef}
      >
        <View
          ref={imageViewRef}
          className="bg-white flex flex-col justify-center items-center"
          style={{
            width: containerWidth,
            height: containerHeight
          }}
        >
          <Image
            accessibilityRole="image"
            ref={imageRef}
            source={{ uri: item.uri }}
            style={{
              resizeMode: 'contain',
              objectFit: 'contain',
              width: width,
              height: height
            }}
          />
        </View>
      </ViewShot>
    </View>
  );
}

export function getShortenedFileName(fileName: string | null | undefined) {
  return fileName !== undefined && fileName !== null
    ? fileName.length > 12
      ? `${fileName?.split('.')[0].substring(0, 10)}...`
      : fileName?.split('.')[0]
    : 'Image';
}
