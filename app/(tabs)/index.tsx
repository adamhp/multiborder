import {
  ActivityIndicator,
  Image,
  Pressable,
  Text,
  View,
  useColorScheme,
} from 'react-native';
import FontAwesome from '@expo/vector-icons/FontAwesome';
import * as ImagePicker from 'expo-image-picker';
import * as MediaLibrary from 'expo-media-library';

import { createRef, useEffect, useRef, useState } from 'react';
import { FlatList } from 'react-native-gesture-handler';
import { useRecoilState } from 'recoil';
import { imagesPostState, imagesRefs, imagesState } from '../state';
import { manipulateAsync } from 'expo-image-manipulator';
import ViewShot from 'react-native-view-shot';
import { captureRef } from 'react-native-view-shot';

export default function TabOneScreen() {
  const colorScheme = useColorScheme();
  const [images, setImages] = useRecoilState(imagesState);
  const [imagesPost, setImagesPost] = useRecoilState(imagesPostState);
  const [loading, setLoading] = useState<boolean>(false);

  const pickImage = async () => {
    setTimeout(() => {
      setLoading(true);
    }, 250);
    let result = await ImagePicker.launchImageLibraryAsync({
      // selectionLimit: 0, TODO: Freemium
      mediaTypes: ImagePicker.MediaTypeOptions.Images,
      allowsMultipleSelection: true,
      quality: 1,
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
    <View className='relative flex-1 flex-col items-center justify-center p-2'>
      <ImagesContainer>
        {loading ? (
          <ActivityIndicator size='large' />
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
      <View className='flex-1 h-1/5 justify-center items-center'>
        {images.length === 0 ? (
          <Pressable
            className='rounded-full bg-zinc-700 w-20 h-20 flex justify-center items-center active:bg-zinc-800'
            onPress={pickImage}
          >
            {({ pressed }) => (
              <FontAwesome name='plus-circle' size={40} color='white' />
            )}
          </Pressable>
        ) : (
          <Pressable
            className='rounded-full bg-zinc-700 w-20 h-20 flex justify-center items-center active:bg-zinc-800'
            onPress={clearImages}
          >
            {({ pressed }) => (
              <FontAwesome name='close' size={40} color='white' />
            )}
          </Pressable>
        )}
      </View>
    </View>
  );
}

function ImagesContainer({
  children,
}: React.ComponentPropsWithoutRef<typeof View>) {
  return (
    <View className='flex h-2/5 justify-center items-center m-2 p-2'>
      {children}
    </View>
  );
}

export function ImageThumbnail({
  item,
  removeImage,
}: {
  item: ImagePicker.ImagePickerAsset;
  removeImage: (image: ImagePicker.ImagePickerAsset) => void;
}) {
  const aspectRatio = item.width / item.height;
  const maxHeight = 200;
  const height = Math.min(maxHeight, 160 / aspectRatio);
  const width = height * aspectRatio;
  return (
    <View className='items-center flex flex-col mt-2 relative mx-4'>
      <Text className='text-xs text-zinc-500 font-space'>
        {getShortenedFileName(item.fileName)}
      </Text>
      <Pressable
        onPress={() => removeImage(item)}
        className='absolute top-0 -right-4 z-10 rounded-full bg-zinc-700/50 w-8 h-8 flex justify-center items-center active:bg-zinc-800'
      >
        {({ pressed }) => (
          <FontAwesome name='close' size={20} color='rgb(244 244 245)' />
        )}
      </Pressable>

      <Image
        source={{ uri: item.uri }}
        style={{
          objectFit: 'contain',
          width: width,
          height: height,
        }}
      />
    </View>
  );
}

export function ImageThumbnailPost({
  item,
  borderSize = 5,
  removeImage,
}: {
  item: ImagePicker.ImagePickerAsset;
  borderSize?: number;
  removeImage: (image: ImagePicker.ImagePickerAsset) => void;
}) {
  const [imagesRefsState, setImagesRefsState] = useRecoilState(imagesRefs);
  const ref = useRef();
  useEffect(() => {
    setImagesRefsState((state) => [
      ...state,
      () => {
        console.log('capturing');
        captureRef(ref, {
          format: 'jpg',
          quality: 1.0, //todo configurable
        }).then(
          (uri) => {
            MediaLibrary.saveToLibraryAsync(uri);
          },
          (error) => console.error('Oops, snapshot failed', error),
        );
      },
    ]);
  }, []);
  const aspectRatio = item.width / item.height;
  const maxHeight = 200 - borderSize * 2;
  const height = Math.min(maxHeight, 160 / aspectRatio - 2 * borderSize);
  const width = height * aspectRatio;
  return (
    <View className='items-center flex flex-col mt-2 relative mx-4'>
      <Text className='text-xs text-zinc-500 font-space'>
        {getShortenedFileName(item.fileName)}
      </Text>
      <ViewShot ref={ref}>
        <View
          className='bg-white flex flex-col justify-center items-center'
          style={{
            width: 160,
            height: 200,
          }}
        >
          <Image
            source={{ uri: item.uri }}
            style={{
              resizeMode: 'contain',
              objectFit: 'contain',
              width: width,
              height: height,
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
