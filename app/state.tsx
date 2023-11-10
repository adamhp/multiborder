import { ImagePickerAsset } from 'expo-image-picker';
import { MutableRefObject, Ref, RefObject } from 'react';
import { View } from 'react-native';
import ViewShot from 'react-native-view-shot';
import { atom } from 'recoil';

export const imagesState = atom<ImagePickerAsset[]>({
  key: 'images',
  default: [],
});

export const imagesPostState = atom<ImagePickerAsset[]>({
  key: 'imagesPost',
  default: [],
});

export const imagesRefs = atom<Function[]>({
  key: 'imagesRefs',
  default: [],
});
