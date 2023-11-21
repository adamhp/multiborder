import FontAwesome from '@expo/vector-icons/FontAwesome';
import clsx from 'clsx';
import * as ImagePicker from 'expo-image-picker';
import { useEffect, useRef } from 'react';
import { Image, Pressable, PressableProps, Text, View } from 'react-native';
import ViewShot from 'react-native-view-shot';
import { useRecoilState } from 'recoil';
import { captureFunctionsState, settingsState } from '../lib/state';
import { captureImage, getShortenedFileName } from '../lib/util';

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
  removeImage,
  size = 200,
  className
}: {
  item: ImagePicker.ImagePickerAsset;
  removeImage: (image: ImagePicker.ImagePickerAsset) => void;
  size?: number;
  className?: string;
}) {
  const aspectRatio = item.width / item.height;
  let height = aspectRatio <= 1 ? size : size / aspectRatio;
  let width = aspectRatio > 1 ? size : height * aspectRatio;
  return (
    <View className={clsx('items-center flex flex-col relative', className)}>
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

export function ImageThumbnailPost({
  item,
  borderSize = 5,
  className
}: {
  item: ImagePicker.ImagePickerAsset;
  borderSize?: number;
  className?: string;
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
  const desiredAspectRatio =
    settings.desiredAspectRatio === -1
      ? aspectRatio
      : settings.desiredAspectRatio;

  const weightedBorderSize = Math.ceil(
    10 * borderSize * (settings.desiredSize / Math.max(item.width, item.height))
  );

  // Set container size based on desired size and desired aspect ratio
  const containerHeight = settings.desiredSize;
  const containerWidth = settings.desiredSize * desiredAspectRatio;

  // Set image size based on container size and original aspect ratio
  let height = containerHeight;
  let width = height * aspectRatio;

  // If original aspect ratio causes width to be greater than container,
  // use width as long edge and adjust height to match
  if (width > containerWidth) {
    width = containerWidth;
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
          desiredAspectRatio,
          desiredSize,
          viewShotRef
        });
        setSettings((state) => ({ ...state, desiredSize: 200 }));
      }
    }));
  }, [settings]);

  return (
    <View className={clsx('items-center flex flex-col relative', className)}>
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
          className="flex flex-col justify-center items-center"
          style={{
            padding: 2 * weightedBorderSize,
            backgroundColor: settings.borderColor,
            width: containerWidth,
            height: containerHeight
          }}
        >
          <Image
            accessibilityRole="image"
            ref={imageRef}
            source={{ uri: item.uri }}
            className="border-collapse"
            style={{
              resizeMode: 'contain',
              objectFit: 'contain',
              width: '100%',
              height: '100%'
            }}
          />
        </View>
      </ViewShot>
    </View>
  );
}

function solve(a: number, b: number, c: number) {
  var result = (-1 * b + Math.sqrt(Math.pow(b, 2) - 4 * a * c)) / (2 * a);
  var result2 = (-1 * b - Math.sqrt(Math.pow(b, 2) - 4 * a * c)) / (2 * a);
  return result + '<br>' + result2;
}
